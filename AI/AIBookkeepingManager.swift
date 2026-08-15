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

enum AIProvider: String, Codable, CaseIterable {
    case poke = "Poke（绯儿 Fei Er）"
    case openAICompatible = "OpenAI 兼容接口"
    case deepSeek = "DeepSeek"
    case claude = "Claude"
}

enum AIBookkeepingError: LocalizedError {
    case invalidInput
    case invalidResponse
    case unbalancedProposal
    case lowConfidence
    case serverStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidInput: return "请输入需要解析的记账文本。"
        case .invalidResponse: return "AI 服务没有返回有效的记账结果，请检查服务地址和模型响应格式。"
        case .unbalancedProposal: return "AI 生成的分录不平衡，未创建交易。"
        case .lowConfidence: return "AI 返回的记账置信度无效，请核对服务响应。"
        case .serverStatus(let code): return "AI 服务请求失败（HTTP \(code)），请稍后重试或检查接口设置。"
        }
    }
}

@MainActor
final class AIBookkeepingManager: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var lastReply = ""

    func parse(text: String) async throws -> TransactionProposal {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw AIBookkeepingError.invalidInput }

        let configuration = try AIConfigurationStore.load()
        let data = try await send(
            configuration: configuration,
            input: ["文本": input]
        )
        let proposal = try decoder.decode(TransactionProposal.self, from: data)
        try validate(proposal)
        lastReply = "AI 已整理好分录，请确认后保存。"
        return proposal
    }

    /// 使用与解析相同的授权和请求协议检查服务可达性；不会写入任何账务数据。
    func testConnection() async throws -> String {
        let configuration = try AIConfigurationStore.load()
        _ = try await send(
            configuration: configuration,
            input: ["文本": "连接测试，请仅返回一笔平衡的示例分录。", "测试": "true"]
        )
        let result = "已连接到 \(configuration.provider.rawValue)。"
        lastReply = result
        return result
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func validate(_ proposal: TransactionProposal) throws {
        guard !proposal.payee.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !proposal.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIBookkeepingError.invalidResponse
        }
        guard (0...1).contains(proposal.confidence) else {
            throw AIBookkeepingError.lowConfidence
        }
        guard proposal.postings.count >= 2,
              proposal.postings.allSatisfy({
                  !$0.account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                  $0.amount == $0.amount.roundedToCents
              }),
              proposal.postings.reduce(Decimal.zero, { $0 + $1.amount }).roundedToCents == 0 else {
            throw AIBookkeepingError.unbalancedProposal
        }
    }

    private func send(
        configuration: AIServiceConfiguration,
        input: [String: String]
    ) async throws -> Data {
        isLoading = true
        defer { isLoading = false }

        var lastError: Error?
        for attempt in 0...1 {
            do {
                var request = URLRequest(url: configuration.endpoint, timeoutInterval: 35)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
                request.httpBody = try JSONSerialization.data(withJSONObject: [
                    "provider": configuration.provider.rawValue,
                    "input": input
                ])

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw AIBookkeepingError.invalidResponse
                }
                guard (200..<300).contains(http.statusCode) else {
                    throw AIBookkeepingError.serverStatus(http.statusCode)
                }
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
        if case AIBookkeepingError.serverStatus(let status) = error {
            return status == 408 || status == 429 || (500...599).contains(status)
        }
        guard let urlError = error as? URLError else { return false }
        return [.timedOut, .networkConnectionLost, .cannotConnectToHost, .notConnectedToInternet].contains(urlError.code)
    }
}
