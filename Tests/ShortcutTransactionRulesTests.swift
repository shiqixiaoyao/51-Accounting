import XCTest
@testable import Accounting51

final class ShortcutTransactionRulesTests: XCTestCase {
    func testShortcutAmountNormalizesToCents() throws {
        let value = try ShortcutTransactionRules.normalizedAmount(from: 12.5)
        XCTAssertEqual(value, Decimal(string: "12.50"))
    }

    func testShortcutAmountRejectsMoreThanTwoDecimalPlaces() {
        XCTAssertThrowsError(try ShortcutTransactionRules.normalizedAmount(from: 12.345)) { error in
            XCTAssertEqual(error as? ShortcutTransactionError, .invalidAmount)
        }
    }

    func testShortcutAmountRejectsZeroAndNegativeValues() {
        XCTAssertThrowsError(try ShortcutTransactionRules.normalizedAmount(from: 0))
        XCTAssertThrowsError(try ShortcutTransactionRules.normalizedAmount(from: -5))
    }

    func testPendingShortcutRouteIsConsumedOnce() {
        ShortcutRouteStore.set(.aiAccounting)
        XCTAssertEqual(ShortcutRouteStore.consume(), .aiAccounting)
        XCTAssertNil(ShortcutRouteStore.consume())
    }
}
