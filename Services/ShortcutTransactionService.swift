import Foundation
import SwiftData

struct ShortcutTransactionReceipt: Equatable {
    let payee: String
    let amount: Decimal
    let currencyCode: String
    let ledgerCategory: String
}

enum ShortcutTransactionError: LocalizedError, Equatable {
    case invalidAmount
    case accountNotFound(String)
    case invalidCategory(String)

    var errorDescription: String? {
        switch self {
        case .invalidAmount: return "金额必须大于零且最多保留两位小数。"
        case .accountNotFound(let name): return "未找到账户“\(name)”。请使用账户管理中的账户名称。"
        case .invalidCategory(let name): return "分类“\(name)”不属于当前收入或支出分类。"
        }
    }
}

enum ShortcutTransactionRules {
    static func normalizedAmount(from value: Double) throws -> Decimal {
        let cents = (value * 100).rounded()
        guard value > 0, abs(value * 100 - cents) < 0.000_001 else {
            throw ShortcutTransactionError.invalidAmount
        }
        return (Decimal(Int(cents)) / 100).roundedToCents
    }

    static func resolveAccount(named value: String, from accounts: [Account]) throws -> Account {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let account = accounts.first(where: {
            $0.name.caseInsensitiveCompare(normalized) == .orderedSame ||
            $0.ledgerName.caseInsensitiveCompare(normalized) == .orderedSame
        }) else {
            throw ShortcutTransactionError.accountNotFound(normalized)
        }
        return account
    }

    static func resolveCategory(
        named value: String,
        kind: TransactionEntryKind,
        storedCategories: [Category]
    ) throws -> LedgerCategoryOption {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = LedgerCategoryCatalog.options(for: kind, storedCategories: storedCategories)
        guard let option = options.first(where: {
            $0.name.caseInsensitiveCompare(normalized) == .orderedSame
        }) else {
            throw ShortcutTransactionError.invalidCategory(normalized)
        }
        return option
    }
}

enum ShortcutPersistence {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: Account.self, BookkeepingTransaction.self, Posting.self, Category.self)
        } catch {
            fatalError("无法初始化快捷指令账本存储：\(error.localizedDescription)")
        }
    }()
}

@MainActor
enum ShortcutTransactionService {
    static func record(
        kind: TransactionEntryKind,
        amount: Double,
        accountName: String,
        categoryName: String,
        payee: String,
        note: String?
    ) throws -> ShortcutTransactionReceipt {
        let context = ModelContext(ShortcutPersistence.container)
        let accounts = try context.fetch(FetchDescriptor<Account>())
        let categories = try context.fetch(FetchDescriptor<Category>())
        let decimalAmount = try ShortcutTransactionRules.normalizedAmount(from: amount)
        let account = try ShortcutTransactionRules.resolveAccount(named: accountName, from: accounts)
        let category = try ShortcutTransactionRules.resolveCategory(
            named: categoryName,
            kind: kind,
            storedCategories: categories
        )
        let normalizedPayee = payee.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPayee = normalizedPayee.isEmpty ? category.name : normalizedPayee
        let postings = try TransactionEntryDraft(
            kind: kind,
            amount: decimalAmount,
            sourceAccount: account,
            destinationAccount: nil,
            category: category,
            payee: resolvedPayee
        ).makePostings()
        try TransactionService.create(
            payee: resolvedPayee,
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            currencyCode: account.currencyCode,
            source: "快捷指令",
            postings: postings,
            in: context
        )
        return ShortcutTransactionReceipt(
            payee: resolvedPayee,
            amount: decimalAmount,
            currencyCode: account.currencyCode,
            ledgerCategory: category.ledgerName
        )
    }
}

@MainActor
enum ShortcutBackupService {
    static func backupNow() async throws -> CloudBackupReceipt {
        let context = ModelContext(ShortcutPersistence.container)
        let accounts = try context.fetch(FetchDescriptor<Account>())
        let categories = try context.fetch(FetchDescriptor<Category>())
        let transactions = try context.fetch(FetchDescriptor<BookkeepingTransaction>())
        let configuration = try WebDAVSettingsStore.load()
        let data = try DataTransferService.backup(
            accounts: accounts,
            categories: categories,
            transactions: transactions
        )
        return try await BackupManager().uploadWebDAV(
            data: data,
            filename: "51-accounting-backup-latest.json",
            configuration: configuration
        )
    }
}
