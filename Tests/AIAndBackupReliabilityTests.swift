import XCTest
@testable import Accounting51

final class AIAndBackupReliabilityTests: XCTestCase {
    func testAIConfigurationAcceptsHTTPSAndTrimsCredentials() throws {
        let configuration = try AIConfigurationStore.makeConfiguration(
            provider: .openAICompatible,
            endpointText: "  https://api.example.com/v1/bookkeeping  ",
            apiKey: "  secret-key  "
        )

        XCTAssertEqual(configuration.endpoint.absoluteString, "https://api.example.com/v1/bookkeeping")
        XCTAssertEqual(configuration.apiKey, "secret-key")
        XCTAssertEqual(configuration.provider, .openAICompatible)
    }

    func testAIConfigurationRejectsInsecureRemoteHTTP() {
        XCTAssertThrowsError(
            try AIConfigurationStore.makeConfiguration(
                provider: .deepSeek,
                endpointText: "http://api.example.com/parse",
                apiKey: "key"
            )
        ) { error in
            XCTAssertEqual(error as? AIConfigurationError, .insecureEndpoint)
        }
    }

    func testWebDAVConfigurationRequiresHTTPSUsernameAndPassword() throws {
        let configuration = try WebDAVSettingsStore.makeConfiguration(
            endpointText: "https://dav.example.com/accounting/",
            username: "  alice ",
            password: " app-password "
        )

        XCTAssertEqual(configuration.baseURL.absoluteString, "https://dav.example.com/accounting/")
        XCTAssertEqual(configuration.username, "alice")
        XCTAssertEqual(configuration.password, "app-password")
    }

    func testWebDAVConfigurationRejectsMissingPassword() {
        XCTAssertThrowsError(
            try WebDAVSettingsStore.makeConfiguration(
                endpointText: "https://dav.example.com/",
                username: "alice",
                password: " "
            )
        ) { error in
            XCTAssertEqual(error as? WebDAVConfigurationError, .missingPassword)
        }
    }

    func testBackupPreflightRejectsUnbalancedTransactionsBeforeRestore() {
        let backup = AccountingBackup(
            accounts: [],
            categories: [],
            transactions: [
                TransactionRecord(
                    id: UUID(),
                    date: .now,
                    payee: "损坏记录",
                    note: "",
                    currencyCode: "CNY",
                    source: "测试",
                    createdAt: .now,
                    postings: [
                        PostingRecord(id: UUID(), accountName: "Assets:现金", amount: 10, memo: "")
                    ]
                )
            ]
        )

        XCTAssertThrowsError(try DataTransferService.validateBackup(backup)) { error in
            XCTAssertEqual(error as? DataTransferError, .unbalancedTransaction("损坏记录"))
        }
    }

    func testBackupSummaryCountsAllRecords() {
        let backup = AccountingBackup(
            accounts: [AccountRecord(id: UUID(), name: "现金", typeRawValue: "asset", currencyCode: "CNY", openingBalance: 0, isLiability: false, createdAt: .now)],
            categories: [CategoryRecord(id: UUID(), name: "餐饮", icon: "fork.knife", isIncome: false, colorHex: "#DC2626")],
            transactions: [
                TransactionRecord(
                    id: UUID(), date: .now, payee: "午餐", note: "", currencyCode: "CNY", source: "测试", createdAt: .now,
                    postings: [
                        PostingRecord(id: UUID(), accountName: "Expenses:餐饮", amount: 10, memo: ""),
                        PostingRecord(id: UUID(), accountName: "Assets:现金", amount: -10, memo: "")
                    ]
                )
            ]
        )

        let summary = DataTransferService.summary(for: backup)
        XCTAssertEqual(summary.accountCount, 1)
        XCTAssertEqual(summary.categoryCount, 1)
        XCTAssertEqual(summary.transactionCount, 1)
        XCTAssertEqual(summary.postingCount, 2)
    }
}
