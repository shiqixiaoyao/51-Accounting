import Foundation

extension Decimal {
    /// Banker's rounding to exactly two decimal places.
    var roundedToCents: Decimal {
        var source = self
        var result = Decimal.zero
        NSDecimalRound(&result, &source, 2, .bankers)
        return result
    }
}
