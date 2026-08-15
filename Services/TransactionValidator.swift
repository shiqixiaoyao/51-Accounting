import Foundation

/// 复式记账校验：所有金额统一按分厘精度校验。
struct TransactionValidator {
    static func validate(_ transaction: BookkeepingTransaction) -> Result<Void, ValidationError> {
        validate(postings: transaction.postings)
    }

    static func validate(postings: [Posting]) -> Result<Void, ValidationError> {
        guard postings.count >= 2 else { return .failure(.requiresAtLeastTwoPostings) }
        guard postings.allSatisfy({ posting in
            !posting.accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else { return .failure(.missingAccount) }
        guard postings.allSatisfy({ posting in
            posting.amount == posting.amount.roundedToCents
        }) else { return .failure(.precisionExceeded) }
        let total = postings.reduce(Decimal.zero) { partial, posting in
            partial + posting.amount
        }.roundedToCents
        guard total == 0 else { return .failure(.unbalanced(total: total)) }
        return .success(())
    }

    enum ValidationError: LocalizedError {
        case requiresAtLeastTwoPostings
        case missingAccount
        case precisionExceeded
        case unbalanced(total: Decimal)

        var errorDescription: String? {
            switch self {
            case .requiresAtLeastTwoPostings: return "一笔交易至少需要两条分录。"
            case .missingAccount: return "每条分录都必须指定账户。"
            case .precisionExceeded: return "金额最多保留两位小数。"
            case .unbalanced(let total): return "分录未平衡，差额为 \(NSDecimalNumber(decimal: total).stringValue)。"
            }
        }
    }
}
