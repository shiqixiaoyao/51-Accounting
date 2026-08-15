import Foundation

/// 账本计算服务：实时聚合期初余额与全部分录，不依赖缓存值。
struct TransactionService {
    static func balance(for account: Account, transactions: [BookkeepingTransaction]) -> Decimal {
        let movement = transactions.flatMap(\.postings).filter { posting in
            posting.accountName == account.name || posting.accountName == account.ledgerName || posting.accountName == account.ledgerName.replacingOccurrences(of: "Assets:", with: "") || posting.accountName == account.ledgerName.replacingOccurrences(of: "Liabilities:", with: "")
        }.reduce(Decimal.zero) { $0 + $1.amount }
        let signedMovement: Decimal
        switch account.type {
        case .asset, .expense: signedMovement = movement
        case .liability, .equity, .income: signedMovement = -movement
        }
        return (account.openingBalance + signedMovement).roundedToCents
    }

    static func balances(accounts: [Account], transactions: [BookkeepingTransaction]) -> [UUID: Decimal] {
        Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, balance(for: $0, transactions: transactions)) })
    }

    static func totalAssets(accounts: [Account], transactions: [BookkeepingTransaction]) -> Decimal {
        accounts.filter { $0.type == .asset }.reduce(Decimal.zero) { $0 + balance(for: $1, transactions: transactions) }.roundedToCents
    }

    static func totalLiabilities(accounts: [Account], transactions: [BookkeepingTransaction]) -> Decimal {
        accounts.filter { $0.type == .liability }.reduce(Decimal.zero) { $0 + balance(for: $1, transactions: transactions) }.roundedToCents
    }

    /// 全负债模型下的净资产 = 资产 - 负债。
    static func netAssets(accounts: [Account], transactions: [BookkeepingTransaction]) -> Decimal {
        (totalAssets(accounts: accounts, transactions: transactions) - totalLiabilities(accounts: accounts, transactions: transactions)).roundedToCents
    }
}
