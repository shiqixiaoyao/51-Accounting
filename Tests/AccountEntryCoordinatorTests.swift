import XCTest
@testable import Accounting51

final class AccountEntryCoordinatorTests: XCTestCase {
    func testMakeDraftTrimsNameAndNormalizesCurrency() throws {
        let draft = try AccountEntryCoordinator.makeDraft(
            name: "  招商银行  ",
            type: .asset,
            currencyCode: " cny ",
            existingAccountNames: ["现金"]
        )

        XCTAssertEqual(draft.name, "招商银行")
        XCTAssertEqual(draft.type, .asset)
        XCTAssertEqual(draft.currencyCode, "CNY")
    }

    func testMakeDraftRejectsEmptyName() {
        XCTAssertThrowsError(
            try AccountEntryCoordinator.makeDraft(
                name: "   ",
                type: .asset,
                currencyCode: "CNY",
                existingAccountNames: []
            )
        ) { error in
            XCTAssertEqual(error as? AccountEntryError, .missingName)
        }
    }

    func testMakeDraftRejectsEmptyCurrency() {
        XCTAssertThrowsError(
            try AccountEntryCoordinator.makeDraft(
                name: "现金",
                type: .asset,
                currencyCode: " ",
                existingAccountNames: []
            )
        ) { error in
            XCTAssertEqual(error as? AccountEntryError, .missingCurrency)
        }
    }

    func testMakeDraftRejectsCaseInsensitiveDuplicateName() {
        XCTAssertThrowsError(
            try AccountEntryCoordinator.makeDraft(
                name: "  cash ",
                type: .asset,
                currencyCode: "CNY",
                existingAccountNames: ["Cash"]
            )
        ) { error in
            XCTAssertEqual(error as? AccountEntryError, .duplicateName)
        }
    }

    func testSelectingNewSourceAccountOnlyChangesSourceSelection() {
        let state = AccountEntryCoordinator.selecting(
            accountNamed: "现金",
            for: .source,
            from: AccountSelectionState(
                sourceAccountName: "旧账户",
                destinationAccountName: "信用卡"
            )
        )

        XCTAssertEqual(state.sourceAccountName, "现金")
        XCTAssertEqual(state.destinationAccountName, "信用卡")
    }

    func testSelectingNewDestinationAccountOnlyChangesDestinationSelection() {
        let state = AccountEntryCoordinator.selecting(
            accountNamed: "储蓄卡",
            for: .destination,
            from: AccountSelectionState(
                sourceAccountName: "现金",
                destinationAccountName: "旧转入账户"
            )
        )

        XCTAssertEqual(state.sourceAccountName, "现金")
        XCTAssertEqual(state.destinationAccountName, "储蓄卡")
    }
}

