import Foundation
import Combine

/// AI 生成的交易提案，保存前必须由用户在中文界面确认。
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
    case openAICompatible = "OpenAI 兼容接口"
    case deepSeek = "DeepSeek"
    case claude = "Claude"
}

enum AIBookkeepingError: LocalizedError {
    case invalidResponse
    case unbalancedProposal
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "AI 返回的数据无效，请稍后重试。"
        case .unbalancedProposal: return "AI 生成的分录不平衡，未创建交易。"
        }
    }
}

@MainActor
final class AIBookkeepingManager: ObservableObject {
    @Published private(set) var isLoading = false
    var provider: AIProvider = .openAICompatible
    var endpoint: URL?
    var apiKey: String = ""

    func parse(text: String) async throws -> TransactionProposal {
        try await request(input: ["文本": text, "系统提示": "请将中文自然语言转换为借贷平衡的记账交易；识别负债、返现和多账户拆分支付。"])
    }

    func parse(imageData: Data, prompt: String = "请识别这张发票或收据，并生成中文记账交易；处理拆分支付、返现和负债冲销。") async throws -> TransactionProposal {
        try await request(input: ["提示": prompt, "图片数据": imageData.base64EncodedString()])
    }

    private func request(input: [String: String]) async throws -> TransactionProposal {
        guard let endpoint else { throw URLError(.badURL) }
        isLoading = true
        defer { isLoading = false }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: ["服务商": provider.rawValue, "输入": input, "输出格式": "交易提案"])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else { throw AIBookkeepingError.invalidResponse }
        let proposal = try JSONDecoder().decode(TransactionProposal.self, from: data)
        guard proposal.postings.reduce(Decimal.zero, { $0 + $1.amount }) == 0 else { throw AIBookkeepingError.unbalancedProposal }
        return proposal
    }
}
