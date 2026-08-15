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

enum ImportConflict: String, CaseIterable, Identifiable { case merge = "合并（保留现有数据）"; case overwrite = "覆盖同 ID 数据"; case replaceAll = "清空后恢复"; var id: String { rawValue } }

enum DataTransferError: LocalizedError { case invalidBackup; case unbalancedTransaction(String); var errorDescription: String? { switch self { case .invalidBackup: return "文件不是有效的 51 记账备份。"; case .unbalancedTransaction(let payee): return "交易“\(payee)”借贷不平衡，已停止导入。" } } }

struct AccountingFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .json, .commaSeparatedText] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

@MainActor
struct DataTransferService {
    static let encoder: JSONEncoder = { let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; e.dateEncodingStrategy = .iso8601; return e }()
    static let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()

    static func backup(accounts: [Account], categories: [Category], transactions: [BookkeepingTransaction]) throws -> Data {
        let value = AccountingBackup(accounts: accounts.map { AccountRecord(id: $0.id, name: $0.name, typeRawValue: $0.typeRawValue, currencyCode: $0.currencyCode, openingBalance: $0.openingBalance, isLiability: $0.isLiability, createdAt: $0.createdAt) }, categories: categories.map { CategoryRecord(id: $0.id, name: $0.name, icon: $0.icon, isIncome: $0.isIncome, colorHex: $0.colorHex) }, transactions: transactions.map { tx in TransactionRecord(id: tx.id, date: tx.date, payee: tx.payee, note: tx.note, currencyCode: tx.currencyCode, source: tx.source, createdAt: tx.createdAt, postings: tx.postings.map { PostingRecord(id: $0.id, accountName: $0.accountName, amount: $0.amount, memo: $0.memo) }) })
        return try encoder.encode(value)
    }

    static func readBackup(_ data: Data) throws -> AccountingBackup { guard let value = try? decoder.decode(AccountingBackup.self, from: data), value.formatVersion == 1 else { throw DataTransferError.invalidBackup }; return value }

    static func restore(_ backup: AccountingBackup, in context: ModelContext, conflict: ImportConflict) throws {
        guard backup.transactions.allSatisfy({ $0.postings.reduce(Decimal.zero) { $0 + $1.amount } == 0 }) else { throw DataTransferError.unbalancedTransaction(backup.transactions.first(where: { $0.postings.reduce(Decimal.zero) { $0 + $1.amount } != 0 })?.payee ?? "未知") }
        let existingAccounts = try context.fetch(FetchDescriptor<Account>()); let existingCategories = try context.fetch(FetchDescriptor<Category>()); let existingTransactions = try context.fetch(FetchDescriptor<BookkeepingTransaction>())
        if conflict == .replaceAll { existingTransactions.forEach(context.delete); existingAccounts.forEach(context.delete); existingCategories.forEach(context.delete) }
        let accountIDs = Set(existingAccounts.map(\.id)); let categoryIDs = Set(existingCategories.map(\.id)); let transactionIDs = Set(existingTransactions.map(\.id))
        for item in backup.accounts where conflict == .replaceAll || conflict == .merge && !accountIDs.contains(item.id) { let model = Account(name: item.name, type: AccountType(rawValue: item.typeRawValue) ?? .asset, currencyCode: item.currencyCode, openingBalance: item.openingBalance, isLiability: item.isLiability); model.id = item.id; model.createdAt = item.createdAt; context.insert(model) }
        for item in backup.categories where conflict == .replaceAll || conflict == .merge && !categoryIDs.contains(item.id) { let model = Category(name: item.name, icon: item.icon, isIncome: item.isIncome, colorHex: item.colorHex); model.id = item.id; context.insert(model) }
        for item in backup.transactions where conflict == .replaceAll || !transactionIDs.contains(item.id) { let model = BookkeepingTransaction(date: item.date, payee: item.payee, note: item.note, currencyCode: item.currencyCode, source: item.source, postings: item.postings.map { Posting(accountName: $0.accountName, amount: $0.amount, memo: $0.memo) }); model.id = item.id; model.createdAt = item.createdAt; model.postings.forEach { $0.id = item.postings.first(where: { $0.accountName == $0.accountName && $0.amount == $0.amount })?.id ?? $0.id }; context.insert(model) }
        try context.save()
    }

    static func beancount(_ transactions: [BookkeepingTransaction]) -> Data { Data(BeancountExporter().export(transactions).utf8) }
    static func csv(_ transactions: [BookkeepingTransaction]) -> Data { let header = "id,date,payee,note,currency,source,account,amount,memo\n"; let rows = transactions.flatMap { tx in tx.postings.map { posting in [tx.id.uuidString, ISO8601DateFormatter().string(from: tx.date), tx.payee, tx.note, tx.currencyCode, tx.source, posting.accountName, NSDecimalNumber(decimal: posting.amount).stringValue, posting.memo].map(csvEscape).joined(separator: ",") + "\n" } }.joined(); return Data((header + rows).utf8) }
    private static func csvEscape(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
}
