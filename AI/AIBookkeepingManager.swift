import Foundation
import Combine

struct TransactionProposal: Codable, Identifiable {
    let id: UUID
    var date: Date
    var payee: String
    var note: String
    var currencyCode: String
    var postings: [ProposalPosting]
    var confidence: Double
}

struct ProposalPosting: Codable, Identifiable {
    let id: UUID
    var account: String
    var amount: Decimal
    var memo: String?
}

enum AIBookkeepingError: LocalizedError, Equatable {
    case invalidInput
    case invalidResponse
    case unbalancedProposal
    case lowConfidence
    case serverStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidInput: return "请输入需要解析的记账文本。"
        case .invalidResponse: return "AI 服务没有返回有效的记账结果，请检查 Endpoint、模型和响应格式。"
        case .unbalancedProposal: return "AI 生成的分录不平衡或金额超过两位小数，未创建交易。"
        case .lowConfidence: return "AI 返回的记账置信度无效，请核对服务响应。"
        case .serverStatus(let code): return "AI 服务请求失败（HTTP \(code)），请稍后重试或检查接口设置。"
        }
    }
}

enum AIProposalValidator {
    static func validate(_ proposal: TransactionProposal) throws {
        guard !proposal.payee.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !proposal.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIBookkeepingError.invalidResponse
        }
        guard (0...1).contains(proposal.confidence) else { throw AIBookkeepingError.lowConfidence }
        let isBalanced = proposal.postings.count >= 2 &&
            proposal.postings.allSatisfy {
                !$0.account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                $0.amount == $0.amount.roundedToCents
            } &&
            proposal.postings.reduce(Decimal.zero) { $0 + $1.amount }.roundedToCents == 0
        guard isBalanced else { throw AIBookkeepingError.unbalancedProposal }
    }
}

@MainActor
final class AIBookkeepingManager: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var lastReply = ""

    func parse(text: String, provider: AIProvider? = nil) async throws -> TransactionProposal {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw AIBookkeepingError.invalidInput }
        let configuration = try AIConfigurationStore.load(provider: provider)
        let data = try await send(configuration: configuration, input: ["文本": input])
        let proposal = try decodeProposal(data, provider: configuration.provider)
        try AIProposalValidator.validate(proposal)
        lastReply = "AI 已整理好分录，请确认后保存。"
        return proposal
    }

    func testConnection(provider: AIProvider? = nil) async throws -> String {
        let configuration = try AIConfigurationStore.load(provider: provider)
        _ = try await send(configuration: configuration, input: ["文本": "连接测试，请返回 JSON 分录。", "测试": "true"])
        let result = "已连接到 \(configuration.provider.rawValue) · \(configuration.model)。"
        lastReply = result
        return result
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func decodeProposal(_ data: Data, provider: AIProvider) throws -> TransactionProposal {
        if let proposal = try? decoder.decode(TransactionProposal.self, from: data) { return proposal }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIBookkeepingError.invalidResponse
        }
        if let proposal = object["proposal"], JSONSerialization.isValidJSONObject(proposal) {
            return try decoder.decode(TransactionProposal.self, from: JSONSerialization.data(withJSONObject: proposal))
        }
        let content: String?
        switch provider.requestStyle {
        case .chatCompletions:
            content = (((object["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String)
        case .anthropicMessages:
            content = ((object["content"] as? [[String: Any]])?.first?["text"] as? String)
        case .genericJSON:
            content = object["content"] as? String ?? object["result"] as? String
        }
        guard let content, let proposalData = content.data(using: .utf8) else { throw AIBookkeepingError.invalidResponse }
        return try decoder.decode(TransactionProposal.self, from: proposalData)
    }

    private func send(configuration: AIServiceConfiguration, input: [String: String]) async throws -> Data {
        isLoading = true
        defer { isLoading = false }
        let payload = try AIRequestPayload(configuration: configuration, input: input)
        var lastError: Error?
        for attempt in 0...1 {
            do {
                let request = try makeRequest(configuration: configuration, payload: payload)
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw AIBookkeepingError.invalidResponse }
                guard (200..<300).contains(http.statusCode) else { throw AIBookkeepingError.serverStatus(http.statusCode) }
                return data
            } catch {
                lastError = error
                guard attempt == 0, shouldRetry(error) else { break }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
        throw lastError ?? AIBookkeepingError.invalidResponse
    }

    private func makeRequest(configuration: AIServiceConfiguration, payload: AIRequestPayload) throws -> URLRequest {
        var request = URLRequest(url: configuration.endpoint, timeoutInterval: 35)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let text = payload.input["文本"] ?? payload.input.values.first ?? ""
        let base: [String: Any] = ["provider": payload.provider, "model": payload.model, "input": payload.input]

        switch configuration.provider.requestStyle {
        case .genericJSON:
            request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: base)
        case .chatCompletions:
            request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
            var body = base
            body["messages"] = [["role": "system", "content": "你是严格复式记账助手，只返回符合 TransactionProposal 的 JSON。"], ["role": "user", "content": text]]
            body["response_format"] = ["type": "json_object"]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        case .anthropicMessages:
            request.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            var body = base
            body["max_tokens"] = 1024
            body["system"] = "你是严格复式记账助手，只返回符合 TransactionProposal 的 JSON。"
            body["messages"] = [["role": "user", "content": text]]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    private func shouldRetry(_ error: Error) -> Bool {
        if case AIBookkeepingError.serverStatus(let status) = error { return status == 408 || status == 429 || (500...599).contains(status) }
        guard let urlError = error as? URLError else { return false }
        return [.timedOut, .networkConnectionLost, .cannotConnectToHost, .notConnectedToInternet].contains(urlError.code)
    }
}
