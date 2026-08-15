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
        let previousSourceID = UUID()
        let destinationID = UUID()
        let selectedSourceID = UUID()
        let state = AccountEntryCoordinator.selecting(
            accountID: selectedSourceID,
            for: .source,
            from: AccountSelectionState(
                sourceAccountID: previousSourceID,
                destinationAccountID: destinationID
            )
        )

        XCTAssertEqual(state.sourceAccountID, selectedSourceID)
        XCTAssertEqual(state.destinationAccountID, destinationID)
    }

    func testSelectingNewDestinationAccountOnlyChangesDestinationSelection() {
        let sourceID = UUID()
        let previousDestinationID = UUID()
        let selectedDestinationID = UUID()
        let state = AccountEntryCoordinator.selecting(
            accountID: selectedDestinationID,
            for: .destination,
            from: AccountSelectionState(
                sourceAccountID: sourceID,
                destinationAccountID: previousDestinationID
            )
        )

        XCTAssertEqual(state.sourceAccountID, sourceID)
        XCTAssertEqual(state.destinationAccountID, selectedDestinationID)
    }
}
