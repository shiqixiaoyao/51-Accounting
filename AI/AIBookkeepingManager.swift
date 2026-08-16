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

    private let systemPrompt = """
    你是一个严格的复式记账助手。根据用户描述生成一笔符合 Beancount 约定的交易分录。
    只返回一个有效 JSON 对象，不要 Markdown、代码围栏、解释或其他文字。
    JSON 必须完全匹配以下结构：
    {"id":"UUID","date":"YYYY-MM-DDT00:00:00Z","payee":"string","note":"string","currencyCode":"CNY","postings":[{"id":"UUID","account":"Assets:... or Liabilities:... or Equity:... or Income:... or Expenses:...","amount":0.00,"memo":"string or null"}],"confidence":0.0}
    金额使用数字并保留两位小数；借方为正、贷方为负；至少两个 posting，所有 posting 的 amount 之和必须严格等于 0。
    不确定时仍返回最合理的分录，但降低 confidence；不要省略任何字段或 UUID。
    """

    func parse(text: String, provider: AIProvider? = nil) async throws -> TransactionProposal {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw AIBookkeepingError.invalidInput }
        let configuration = try AIConfigurationStore.load(provider: provider)
        let data = try await send(configuration: configuration, userMessage: input)
        let proposal = try decodeProposal(data)
        try AIProposalValidator.validate(proposal)
        lastReply = "AI 已整理好分录，请确认后保存。"
        return proposal
    }

    func testConnection(provider: AIProvider? = nil) async throws -> String {
        let configuration = try AIConfigurationStore.load(provider: provider)
        _ = try await send(configuration: configuration, userMessage: "连接测试。请返回一笔金额为 0 的有效 JSON 分录，仍须包含完整字段、至少两个金额相抵的 posting 和 confidence。")
        let result = "已连接到 \(configuration.provider.rawValue) · \(configuration.model)。"
        lastReply = result
        return result
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func decodeProposal(_ data: Data) throws -> TransactionProposal {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = (((object["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String),
              let proposalData = extractJSON(from: content).data(using: .utf8) else {
            throw AIBookkeepingError.invalidResponse
        }
        do {
            return try decoder.decode(TransactionProposal.self, from: proposalData)
        } catch {
            throw AIBookkeepingError.invalidResponse
        }
    }

    private func extractJSON(from content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            return trimmed
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") else { return trimmed }
        return String(trimmed[start...end])
    }

    private func send(configuration: AIServiceConfiguration, userMessage: String) async throws -> Data {
        isLoading = true
        defer { isLoading = false }
        var request = URLRequest(url: configuration.endpoint, timeoutInterval: 35)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": configuration.model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ],
            "temperature": 0,
            "response_format": ["type": "json_object"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var lastError: Error?
        for attempt in 0...1 {
            do {
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

    private func shouldRetry(_ error: Error) -> Bool {
        if case AIBookkeepingError.serverStatus(let status) = error { return status == 408 || status == 429 || (500...599).contains(status) }
        guard let urlError = error as? URLError else { return false }
        return [.timedOut, .networkConnectionLost, .cannotConnectToHost, .notConnectedToInternet].contains(urlError.code)
    }
}
