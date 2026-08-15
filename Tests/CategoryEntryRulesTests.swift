import XCTest
@testable import Accounting51

final class CategoryEntryRulesTests: XCTestCase {
    func testDefaultCatalogIncludesExpandedExpenseAndIncomeOptions() {
        let expenseNames = LedgerCategoryCatalog.defaultOptions(for: .expense).map(\.name)
        let incomeNames = LedgerCategoryCatalog.defaultOptions(for: .income).map(\.name)

        XCTAssertTrue(expenseNames.contains("医疗健康"))
        XCTAssertTrue(expenseNames.contains("教育学习"))
        XCTAssertTrue(expenseNames.contains("旅行"))
        XCTAssertTrue(incomeNames.contains("兼职收入"))
        XCTAssertTrue(incomeNames.contains("报销"))
        XCTAssertTrue(incomeNames.contains("退款"))
        XCTAssertTrue(LedgerCategoryCatalog.defaultOptions(for: .transfer).isEmpty)
    }

    func testCustomIncomeCategoryIsNormalizedAndExposedToIncomeOnly() throws {
        let draft = try CategoryEntryRules.makeDraft(
            name: "  项目分成  ",
            icon: "chart.line.uptrend",
            kind: .income,
            existingCategories: []
        )
        let category = Category(
            name: draft.name,
            icon: draft.icon,
            isIncome: draft.isIncome,
            colorHex: draft.colorHex
        )

        XCTAssertEqual(draft.name, "项目分成")
        XCTAssertTrue(draft.isIncome)
        XCTAssertEqual(draft.option.ledgerName, "Income:项目分成")
        XCTAssertTrue(LedgerCategoryCatalog.options(for: .income, storedCategories: [category]).contains(draft.option))
        XCTAssertFalse(LedgerCategoryCatalog.options(for: .expense, storedCategories: [category]).contains(draft.option))
    }

    func testDuplicateCategoryIsRejectedWithinSameIncomeOrExpenseType() {
        let existing = [Category(name: "餐饮", icon: "fork.knife", isIncome: false)]

        XCTAssertThrowsError(
            try CategoryEntryRules.makeDraft(
                name: " 餐饮 ",
                icon: "fork.knife",
                kind: .expense,
                existingCategories: existing
            )
        ) { error in
            XCTAssertEqual(error as? CategoryEntryError, .duplicateName)
        }
    }

    func testSameCategoryNameCanExistInDifferentIncomeAndExpenseTypes() throws {
        let existing = [Category(name: "退款", icon: "arrow.uturn.left.circle", isIncome: true)]

        let expenseDraft = try CategoryEntryRules.makeDraft(
            name: "退款",
            icon: "arrow.uturn.left.circle",
            kind: .expense,
            existingCategories: existing
        )

        XCTAssertFalse(expenseDraft.isIncome)
        XCTAssertEqual(expenseDraft.option.ledgerName, "Expenses:退款")
    }
}
