import XCTest
@testable import Accounting51

final class AccountEditingRulesTests: XCTestCase {
    func testMakeDraftNormalizesBankNameCurrencyAndOpeningBalance() throws {
        let draft = try AccountEditingRules.makeDraft(
            name: "  建行 1843  ",
            type: .asset,
            currencyCode: " cny ",
            openingBalanceInput: "120.50",
            existingAccountNames: ["现金"]
        )

        XCTAssertEqual(draft.name, "建行 1843")
        XCTAssertEqual(draft.type, .asset)
        XCTAssertEqual(draft.currencyCode, "CNY")
        XCTAssertEqual(draft.openingBalance, Decimal(string: "120.50"))
        XCTAssertEqual(draft.ledgerName, "Assets:建行 1843")
    }

    func testMakeDraftUsesCanonicalLedgerPrefixForLiability() throws {
        let draft = try AccountEditingRules.makeDraft(
            name: "招行信用卡",
            type: .liability,
            currencyCode: "CNY",
            openingBalanceInput: "0",
            existingAccountNames: []
        )

        XCTAssertEqual(draft.ledgerName, "Liabilities:招行信用卡")
    }

    func testMakeDraftRejectsDuplicateBankNameIgnoringCaseAndWhitespace() {
        XCTAssertThrowsError(
            try AccountEditingRules.makeDraft(
                name: "  ccb 1843 ",
                type: .asset,
                currencyCode: "CNY",
                openingBalanceInput: "0",
                existingAccountNames: ["CCB 1843"]
            )
        ) { error in
            XCTAssertEqual(error as? AccountEditingError, .duplicateName)
        }
    }

    func testMakeDraftRejectsOpeningBalanceWithMoreThanTwoDecimals() {
        XCTAssertThrowsError(
            try AccountEditingRules.makeDraft(
                name: "建行",
                type: .asset,
                currencyCode: "CNY",
                openingBalanceInput: "1.001",
                existingAccountNames: []
            )
        ) { error in
            XCTAssertEqual(error as? AccountEditingError, .precisionExceeded)
        }
    }

    func testRewrittenPostingAccountNameChangesOnlyMatchingOldLedgerPath() {
        let updated = AccountEditingRules.rewrittenPostingAccountName(
            currentPostingAccountName: "Assets:旧建行",
            oldLedgerName: "Assets:旧建行",
            newLedgerName: "Assets:建行 1843"
        )
        let untouched = AccountEditingRules.rewrittenPostingAccountName(
            currentPostingAccountName: "Expenses:餐饮",
            oldLedgerName: "Assets:旧建行",
            newLedgerName: "Assets:建行 1843"
        )

        XCTAssertEqual(updated, "Assets:建行 1843")
        XCTAssertEqual(untouched, "Expenses:餐饮")
    }

    func testLegacyRawAccountNameAlsoMigratesToNewLedgerPath() {
        let updated = AccountEditingRules.rewrittenPostingAccountName(
            currentPostingAccountName: "旧建行",
            oldAccountNames: ["旧建行", "Assets:旧建行"],
            newLedgerName: "Assets:建行 1843"
        )

        XCTAssertEqual(updated, "Assets:建行 1843")
    }
}
