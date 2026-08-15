import XCTest
@testable import Accounting51

final class AIProviderConfigurationTests: XCTestCase {
    func testDeepSeekPresetIncludesCurrentEndpointAndModel() throws {
        let configuration = try AIConfigurationStore.makeConfiguration(
            provider: .deepSeek,
            endpointText: AIProvider.deepSeek.defaultEndpoint,
            model: AIProvider.deepSeek.defaultModel,
            apiKey: " key "
        )
        XCTAssertEqual(configuration.endpoint.absoluteString, "https://api.deepseek.com/chat/completions")
        XCTAssertEqual(configuration.model, "deepseek-v4-flash")
        XCTAssertEqual(configuration.apiKey, "key")
    }

    func testCustomProviderRequiresModel() {
        XCTAssertThrowsError(try AIConfigurationStore.makeConfiguration(
            provider: .custom,
            endpointText: "https://api.example.com/v1/bookkeeping",
            model: " ",
            apiKey: "secret"
        )) { error in
            XCTAssertEqual(error as? AIConfigurationError, .missingModel)
        }
    }

    func testPayloadAlwaysContainsProviderModelAndInput() throws {
        let configuration = try AIConfigurationStore.makeConfiguration(
            provider: .openAICompatible,
            endpointText: "https://api.example.com/v1/chat/completions",
            model: "ledger-model",
            apiKey: "secret"
        )
        let payload = try AIRequestPayload(configuration: configuration, input: ["文本": "午餐 36.50 元"])
        XCTAssertEqual(payload.provider, "openai-compatible")
        XCTAssertEqual(payload.model, "ledger-model")
        XCTAssertEqual(payload.input, ["文本": "午餐 36.50 元"])
    }

    func testProposalValidatorRejectsUnbalancedAndFractionalCentPostings() {
        let proposal = TransactionProposal(
            id: UUID(), date: .now, payee: "测试", note: "", currencyCode: "CNY",
            postings: [
                ProposalPosting(id: UUID(), account: "Expenses:餐饮", amount: Decimal(string: "10.001")!, memo: nil),
                ProposalPosting(id: UUID(), account: "Assets:Cash", amount: -10, memo: nil)
            ], confidence: 0.9
        )
        XCTAssertThrowsError(try AIProposalValidator.validate(proposal)) { error in
            XCTAssertEqual(error as? AIBookkeepingError, .unbalancedProposal)
        }
    }
}

