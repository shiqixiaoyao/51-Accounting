import Foundation

/// 复式记账校验：所有金额统一按人民币分厘精度校验。
struct TransactionValidator {
    static let tolerance: Decimal = 0.01

    static func validate(_ transaction: BookkeepingTransaction) -> Result<Void, ValidationError> {
        validate(postings: transaction.postings)
    }

    static func validate(postings: [Posting]) -> Result<Void, ValidationError> {
        guard postings.count >= 2 else { return .failure(.requiresAtLeastTwoPostings) }
        guard postings.allSatisfy({ !$0.accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return .failure(.missingAccount)
        }
        guard postings.allSatisfy({ $0.amount.isFiniteDecimal && $0.amount.roundedToCents == $0 }) else {
            return .failure(.precisionExceeded)
        }
        let total = postings.reduce(Decimal.zero) { $0 + $1.amount }.roundedToCents
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

private extension Decimal {
    var isFiniteDecimal: Bool { NSDecimalIsNotANumber(self) == false }
}
