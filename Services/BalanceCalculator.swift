import Foundation

struct BalanceCalculator {
    static func balance(for account: Account, transactions: [BookkeepingTransaction]) -> Decimal {
        let names = Set([account.name, account.ledgerName, account.ledgerName.replacingOccurrences(of: "Assets:", with: ""), account.ledgerName.replacingOccurrences(of: "Liabilities:", with: "")])
        let movement = transactions.flatMap { $0.postings }.filter { names.contains($0.accountName) }.reduce(Decimal.zero) { $0 + $1.amount }
        let signed: Decimal
        switch account.type {
        case .asset, .expense: signed = movement
        case .liability, .equity, .income: signed = -movement
        }
        return (account.openingBalance + signed).roundedToCents
    }
    static func balances(accounts: [Account], transactions: [BookkeepingTransaction]) -> [UUID: Decimal] { Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, balance(for: $0, transactions: transactions)) }) }
    static func totalAssets(accounts: [Account], transactions: [BookkeepingTransaction]) -> Decimal { accounts.filter { $0.type == .asset }.reduce(Decimal.zero) { $0 + balance(for: $1, transactions: transactions) }.roundedToCents }
    static func totalLiabilities(accounts: [Account], transactions: [BookkeepingTransaction]) -> Decimal { accounts.filter { $0.type == .liability }.reduce(Decimal.zero) { $0 + balance(for: $1, transactions: transactions) }.roundedToCents }
    static func netAssets(accounts: [Account], transactions: [BookkeepingTransaction]) -> Decimal { (totalAssets(accounts: accounts, transactions: transactions) - totalLiabilities(accounts: accounts, transactions: transactions)).roundedToCents }
}
