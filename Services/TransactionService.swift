import Foundation
import SwiftData

struct TransactionService {
    @discardableResult
    static func create(date: Date = .now, payee: String, note: String = "", currencyCode: String = "CNY", source: String = "手动", postings: [Posting], in context: ModelContext) throws -> BookkeepingTransaction {
        let transaction = BookkeepingTransaction(date: date, payee: payee, note: note, currencyCode: currencyCode, source: source, postings: postings)
        switch TransactionValidator.validate(transaction) {
        case .success:
            context.insert(transaction)
            do { try context.save(); return transaction }
            catch { context.delete(transaction); throw error }
        case .failure(let error): throw error
        }
    }

    static func validateAndInsert(_ transaction: BookkeepingTransaction, in context: ModelContext) throws {
        switch TransactionValidator.validate(transaction) {
        case .success:
            context.insert(transaction)
            do { try context.save() } catch { context.delete(transaction); throw error }
        case .failure(let error): throw error
        }
    }

    static func balance(for account: Account, transactions: [BookkeepingTransaction]) -> Decimal {
        let names = Set([account.name, account.ledgerName, account.ledgerName.replacingOccurrences(of: "Assets:", with: ""), account.ledgerName.replacingOccurrences(of: "Liabilities:", with: "")])
        let movement = transactions.flatMap(\.postings).filter { names.contains($0.accountName) }.reduce(Decimal.zero) { $0 + $1.amount }
        switch account.type { case .asset, .expense: return (account.openingBalance + movement).roundedToCents; case .liability, .equity, .income: return (account.openingBalance - movement).roundedToCents }
    }
    static func balances(accounts: [Account], transactions: [BookkeepingTransaction]) -> [UUID: Decimal] { Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, balance(for: $0, transactions: transactions)) }) }
    static func totalAssets(accounts: [Account], transactions: [BookkeepingTransaction]) -> Decimal { accounts.filter { $0.type == .asset }.reduce(Decimal.zero) { $0 + balance(for: $1, transactions: transactions) }.roundedToCents }
    static func totalLiabilities(accounts: [Account], transactions: [BookkeepingTransaction]) -> Decimal { accounts.filter { $0.type == .liability }.reduce(Decimal.zero) { $0 + balance(for: $1, transactions: transactions) }.roundedToCents }
    static func netAssets(accounts: [Account], transactions: [BookkeepingTransaction]) -> Decimal { (totalAssets(accounts: accounts, transactions: transactions) - totalLiabilities(accounts: accounts, transactions: transactions)).roundedToCents }
}
