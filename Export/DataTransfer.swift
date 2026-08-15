import Foundation
import SwiftUI
import UniformTypeIdentifiers
import SwiftData

struct AccountingBackup: Codable {
    var formatVersion: Int = 1
    var exportedAt: Date = Date()
    var accounts: [AccountRecord]
    var categories: [CategoryRecord]
    var transactions: [TransactionRecord]
}

struct AccountRecord: Codable { var id: UUID; var name: String; var typeRawValue: String; var currencyCode: String; var openingBalance: Decimal; var isLiability: Bool; var createdAt: Date }
struct CategoryRecord: Codable { var id: UUID; var name: String; var icon: String; var isIncome: Bool; var colorHex: String }
struct PostingRecord: Codable { var id: UUID; var accountName: String; var amount: Decimal; var memo: String }
struct TransactionRecord: Codable { var id: UUID; var date: Date; var payee: String; var note: String; var currencyCode: String; var source: String; var createdAt: Date; var postings: [PostingRecord] }

struct BackupSummary: Equatable {
    let exportedAt: Date
    let accountCount: Int
    let categoryCount: Int
    let transactionCount: Int
    let postingCount: Int
}

enum ImportConflict: String, CaseIterable, Identifiable {
    case merge = "合并（保留现有数据）"
    case overwrite = "覆盖同 ID 数据"
    case replaceAll = "清空后恢复"
    var id: String { rawValue }
}

enum DataTransferError: LocalizedError, Equatable {
    case invalidBackup
    case unsupportedVersion
    case duplicateIdentifier
    case unbalancedTransaction(String)

    var errorDescription: String? {
        switch self {
        case .invalidBackup: return "文件不是有效的 51 记账备份。"
        case .unsupportedVersion: return "该备份版本暂不受支持。"
        case .duplicateIdentifier: return "备份中存在重复记录，已停止恢复。"
        case .unbalancedTransaction(let payee): return "交易“\(payee)”借贷不平衡，已停止导入。"
        }
    }
}

struct AccountingFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data, .json, .plainText] }
    static var writableContentTypes: [UTType] { [.data, .json, .plainText] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct DataTransferService {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func backup(
        accounts: [Account],
        categories: [Category],
        transactions: [BookkeepingTransaction],
        scope: BackupScope = .complete
    ) throws -> Data {
        let selectedAccounts = scope == .transactionsOnly ? [] : accounts
        let selectedCategories = scope == .transactionsOnly ? [] : categories
        let selectedTransactions = scope == .setupOnly ? [] : transactions
        let value = AccountingBackup(
            accounts: selectedAccounts.map { AccountRecord(id: $0.id, name: $0.name, typeRawValue: $0.typeRawValue, currencyCode: $0.currencyCode, openingBalance: $0.openingBalance, isLiability: $0.isLiability, createdAt: $0.createdAt) },
            categories: selectedCategories.map { CategoryRecord(id: $0.id, name: $0.name, icon: $0.icon, isIncome: $0.isIncome, colorHex: $0.colorHex) },
            transactions: selectedTransactions.map { transaction in
                TransactionRecord(id: transaction.id, date: transaction.date, payee: transaction.payee, note: transaction.note, currencyCode: transaction.currencyCode, source: transaction.source, createdAt: transaction.createdAt, postings: transaction.postings.map { PostingRecord(id: $0.id, accountName: $0.accountName, amount: $0.amount, memo: $0.memo) })
            }
        )
        try validateBackup(value)
        return try encoder.encode(value)
    }

    static func readBackup(_ data: Data) throws -> AccountingBackup {
        guard let value = try? decoder.decode(AccountingBackup.self, from: data) else {
            throw DataTransferError.invalidBackup
        }
        try validateBackup(value)
        return value
    }

    static func summary(for backup: AccountingBackup) -> BackupSummary {
        BackupSummary(
            exportedAt: backup.exportedAt,
            accountCount: backup.accounts.count,
            categoryCount: backup.categories.count,
            transactionCount: backup.transactions.count,
            postingCount: backup.transactions.reduce(0) { $0 + $1.postings.count }
        )
    }

    /// 在删除或覆写任何本地数据前进行完整预检，避免损坏的云端文件造成不可逆恢复。
    static func validateBackup(_ backup: AccountingBackup) throws {
        guard backup.formatVersion == 1 else { throw DataTransferError.unsupportedVersion }
        guard Set(backup.accounts.map(\.id)).count == backup.accounts.count,
              Set(backup.categories.map(\.id)).count == backup.categories.count,
              Set(backup.transactions.map(\.id)).count == backup.transactions.count else {
            throw DataTransferError.duplicateIdentifier
        }

        for record in backup.transactions {
            let isBalanced = record.postings.count >= 2 &&
                record.postings.allSatisfy {
                    !$0.accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    $0.amount == $0.amount.roundedToCents
                } &&
                record.postings.reduce(Decimal.zero) { $0 + $1.amount }.roundedToCents == 0
            guard isBalanced else {
                throw DataTransferError.unbalancedTransaction(record.payee)
            }
        }
    }

    static func restore(_ backup: AccountingBackup, in context: ModelContext, conflict: ImportConflict) throws {
        try validateBackup(backup)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        let categories = try context.fetch(FetchDescriptor<Category>())
        let transactions = try context.fetch(FetchDescriptor<BookkeepingTransaction>())
        if conflict == .replaceAll {
            transactions.forEach(context.delete)
            accounts.forEach(context.delete)
            categories.forEach(context.delete)
        }

        let accountByID = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        let categoryByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let transactionByID = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) })

        for record in backup.accounts {
            if conflict == .overwrite, let existing = accountByID[record.id] {
                existing.name = record.name
                existing.type = AccountType(rawValue: record.typeRawValue) ?? .asset
                existing.currencyCode = record.currencyCode
                existing.openingBalance = record.openingBalance
            } else if conflict == .replaceAll || (conflict == .merge && accountByID[record.id] == nil) {
                let model = Account(name: record.name, type: AccountType(rawValue: record.typeRawValue) ?? .asset, currencyCode: record.currencyCode, openingBalance: record.openingBalance, isLiability: record.isLiability)
                model.id = record.id
                model.createdAt = record.createdAt
                context.insert(model)
            }
        }

        for record in backup.categories {
            if conflict == .overwrite, let existing = categoryByID[record.id] {
                existing.name = record.name
                existing.icon = record.icon
                existing.isIncome = record.isIncome
                existing.colorHex = record.colorHex
            } else if conflict == .replaceAll || (conflict == .merge && categoryByID[record.id] == nil) {
                let model = Category(name: record.name, icon: record.icon, isIncome: record.isIncome, colorHex: record.colorHex)
                model.id = record.id
                context.insert(model)
            }
        }

        for record in backup.transactions {
            let postings = record.postings.map { Posting(accountName: $0.accountName, amount: $0.amount, memo: $0.memo) }
            if conflict == .overwrite, let existing = transactionByID[record.id] {
                existing.date = record.date
                existing.payee = record.payee
                existing.note = record.note
                existing.currencyCode = record.currencyCode
                existing.source = record.source
                existing.postings = postings
            } else if conflict == .replaceAll || (conflict == .merge && transactionByID[record.id] == nil) {
                let model = BookkeepingTransaction(date: record.date, payee: record.payee, note: record.note, currencyCode: record.currencyCode, source: record.source, postings: postings)
                model.id = record.id
                model.createdAt = record.createdAt
                context.insert(model)
            }
        }
        try context.save()
    }

    static func beancount(_ transactions: [BookkeepingTransaction]) -> Data {
        Data(BeancountExporter().export(transactions).utf8)
    }

    static func csv(_ transactions: [BookkeepingTransaction]) -> Data {
        Data("id,date,payee,note,currency,source,account,amount,memo\n".utf8)
    }
}
