import XCTest
@testable import Accounting51

final class TransactionEntryRulesTests: XCTestCase {
    func testCatalogFiltersExpenseIncomeAndTransferCategories() {
        let stored = [
            Category(name: "医疗", isIncome: false),
            Category(name: "股息", isIncome: true)
        ]

        let expenseNames = LedgerCategoryCatalog.options(for: .expense, storedCategories: stored).map(\.name)
        let incomeNames = LedgerCategoryCatalog.options(for: .income, storedCategories: stored).map(\.name)
        let transferOptions = LedgerCategoryCatalog.options(for: .transfer, storedCategories: stored)

        XCTAssertTrue(expenseNames.contains("医疗"))
        XCTAssertTrue(expenseNames.contains("餐饮"))
        XCTAssertFalse(expenseNames.contains("股息"))
        XCTAssertTrue(incomeNames.contains("股息"))
        XCTAssertTrue(incomeNames.contains("工资"))
        XCTAssertFalse(incomeNames.contains("医疗"))
        XCTAssertTrue(transferOptions.isEmpty)
    }

    func testMoneyInputAcceptsTwoDecimalPlacesAndFormatsFixedScale() throws {
        let amount = try MoneyInput.validatedDecimal(from: "12.30")

        XCTAssertEqual(amount, Decimal(string: "12.30"))
        XCTAssertEqual(MoneyInput.display(amount), "12.30")
    }

    func testMoneyInputRejectsMoreThanTwoDecimalPlaces() {
        XCTAssertThrowsError(try MoneyInput.validatedDecimal(from: "12.345")) { error in
            XCTAssertEqual(error as? MoneyInputError, .precisionExceeded)
        }
    }

    func testExpenseUsesStandardLedgerPathsAndIsBalanced() throws {
        let cash = Account(name: "建行 1843", type: .asset)
        let postings = try TransactionEntryDraft(
            kind: .expense,
            amount: Decimal(string: "28.50")!,
            sourceAccount: cash,
            destinationAccount: nil,
            category: LedgerCategoryOption(name: "餐饮", isIncome: false),
            payee: "午餐"
        ).makePostings()

        XCTAssertEqual(postings.map(\.accountName), ["Expenses:餐饮", "Assets:建行 1843"])
        XCTAssertEqual(postings.map(\.amount), [Decimal(string: "28.50")!, Decimal(string: "-28.50")!])
        XCTAssertEqual(postings.reduce(Decimal.zero) { $0 + $1.amount }, .zero)
    }

    func testExpenseOnLiabilityIncreasesLiabilityAndIsBalanced() throws {
        let card = Account(name: "信用卡 1843", type: .liability)
        let postings = try TransactionEntryDraft(
            kind: .expense,
            amount: 100,
            sourceAccount: card,
            destinationAccount: nil,
            category: LedgerCategoryOption(name: "购物", isIncome: false),
            payee: "商店"
        ).makePostings()

        XCTAssertEqual(postings[1].accountName, "Liabilities:信用卡 1843")
        XCTAssertEqual(postings[1].amount, -100)
        XCTAssertEqual(postings.reduce(Decimal.zero) { $0 + $1.amount }, .zero)
    }

    func testIncomeIncreasesAssetAndUsesIncomeLedgerPath() throws {
        let cash = Account(name: "现金", type: .asset)
        let postings = try TransactionEntryDraft(
            kind: .income,
            amount: Decimal(string: "3000.00")!,
            sourceAccount: cash,
            destinationAccount: nil,
            category: LedgerCategoryOption(name: "工资", isIncome: true),
            payee: "公司"
        ).makePostings()

        XCTAssertEqual(postings.map(\.accountName), ["Assets:现金", "Income:工资"])
        XCTAssertEqual(postings.map(\.amount), [Decimal(string: "3000.00")!, Decimal(string: "-3000.00")!])
        XCTAssertEqual(postings.reduce(Decimal.zero) { $0 + $1.amount }, .zero)
    }

    func testTransferUsesTwoAccountLedgerPathsAndIsBalanced() throws {
        let cash = Account(name: "现金", type: .asset)
        let card = Account(name: "信用卡", type: .liability)
        let postings = try TransactionEntryDraft(
            kind: .transfer,
            amount: 88,
            sourceAccount: cash,
            destinationAccount: card,
            category: nil,
            payee: "账户还款"
        ).makePostings()

        XCTAssertEqual(postings.map(\.accountName), ["Liabilities:信用卡", "Assets:现金"])
        XCTAssertEqual(postings.map(\.amount), [88, -88])
        XCTAssertEqual(postings.reduce(Decimal.zero) { $0 + $1.amount }, .zero)
    }

    func testTransferRejectsSameAccountID() {
        let cash = Account(name: "现金", type: .asset)

        XCTAssertThrowsError(
            try TransactionEntryDraft(
                kind: .transfer,
                amount: 88,
                sourceAccount: cash,
                destinationAccount: cash,
                category: nil,
                payee: "无效转账"
            ).makePostings()
        ) { error in
            XCTAssertEqual(error as? TransactionEntryRuleError, .sameSourceAndDestination)
        }
    }

    func testIncomeRejectsLiabilityAsReceivingAccount() {
        let card = Account(name: "信用卡", type: .liability)

        XCTAssertThrowsError(
            try TransactionEntryDraft(
                kind: .income,
                amount: 100,
                sourceAccount: card,
                destinationAccount: nil,
                category: LedgerCategoryOption(name: "工资", isIncome: true),
                payee: "公司"
            ).makePostings()
        ) { error in
            XCTAssertEqual(error as? TransactionEntryRuleError, .incomeMustEnterAnAssetAccount)
        }
    }
}

