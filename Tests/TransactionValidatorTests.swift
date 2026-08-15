import XCTest
@testable import Accounting51

final class TransactionValidatorTests: XCTestCase {
    func testBalancedPostingsPass() {
        let postings = [Posting(accountName: "Expenses:Food", amount: 10), Posting(accountName: "Cash", amount: -10)]
        guard case .success = TransactionValidator.validate(postings: postings) else { return XCTFail("Expected success") }
    }

    func testUnbalancedPostingsFail() {
        let postings = [Posting(accountName: "Expenses:Food", amount: 10), Posting(accountName: "Cash", amount: -9)]
        guard case .failure(.unbalanced(total: 1)) = TransactionValidator.validate(postings: postings) else { return XCTFail("Expected unbalanced failure") }
    }

    func testRequiresTwoPostings() {
        guard case .failure(.requiresAtLeastTwoPostings) = TransactionValidator.validate(postings: [Posting(accountName: "Cash", amount: 0)]) else { return XCTFail("Expected count failure") }
    }

    func testMissingAccountFails() {
        let postings = [Posting(accountName: "", amount: 10), Posting(accountName: "Cash", amount: -10)]
        guard case .failure(.missingAccount) = TransactionValidator.validate(postings: postings) else { return XCTFail("Expected account failure") }
    }

    func testMoreThanTwoDecimalsFails() {
        let postings = [Posting(accountName: "Expenses:Food", amount: 10.001), Posting(accountName: "Cash", amount: -10.001)]
        guard case .failure(.precisionExceeded) = TransactionValidator.validate(postings: postings) else { return XCTFail("Expected precision failure") }
    }
}
