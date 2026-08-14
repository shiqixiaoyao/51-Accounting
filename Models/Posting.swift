import Foundation
import SwiftData

/// 交易分录：正数和负数共同组成平衡的复式记账记录。
@Model
final class Posting {
    var id: UUID
    var accountName: String
    var amount: Decimal
    var memo: String
    var transaction: BookkeepingTransaction?

    init(accountName: String, amount: Decimal, memo: String = "") {
        self.id = UUID()
        self.accountName = accountName
        self.amount = amount
        self.memo = memo
    }
}
