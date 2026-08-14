import Foundation
import SwiftData

/// 一笔交易由一组借贷平衡的分录组成。
@Model
final class BookkeepingTransaction {
    var id: UUID
    var date: Date
    var payee: String
    var note: String
    var currencyCode: String
    var source: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var postings: [Posting]

    init(date: Date = .now, payee: String, note: String = "", currencyCode: String = "CNY", source: String = "手动录入", postings: [Posting] = []) {
        self.id = UUID()
        self.date = date
        self.payee = payee
        self.note = note
        self.currencyCode = currencyCode
        self.source = source
        self.createdAt = .now
        self.postings = postings
    }

    var isBalanced: Bool { postings.reduce(Decimal.zero) { $0 + $1.amount } == 0 }
}
