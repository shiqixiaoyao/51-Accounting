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
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw AIBookkeepingError.invalidResponse }
        if endpoint != nil { return try await request(input: ["文本": input, "系统提示": "请将中文自然语言转换为借贷平衡的记账交易；识别负债、返现和多账户拆分支付。"]) }
        return try localParse(input)
    }

    func parse(imageData: Data, prompt: String = "请识别这张发票或收据，并生成中文记账交易；处理拆分支付、返现和负债冲销。") async throws -> TransactionProposal {
        try await request(input: ["提示": prompt, "图片数据": imageData.base64EncodedString()])
    }

    private func localParse(_ text: String) throws -> TransactionProposal {
        let pattern = #"(?<![\d.])\d+(?:\.\d{1,2})?(?![\d.])"#
        guard let match = text.range(of: pattern, options: .regularExpression), let amount = Decimal(string: String(text[match])) else { throw AIBookkeepingError.invalidResponse }
        let account = Self.accountName(in: text)
        let payee = text.replacingOccurrences(of: String(text[match]), with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let category = text.contains("交通") || text.contains("打车") ? "交通" : text.contains("买") || text.contains("购物") ? "购物" : "餐饮"
        let isIncome = text.contains("工资") || text.contains("收入") || text.contains("返现")
        let expenseAccount = isIncome ? "Income:\(category)" : "Expenses:\(category)"
        let postings = isIncome ? [ProposalPosting(id: UUID(), account: account, amount: amount, memo: payee), ProposalPosting(id: UUID(), account: expenseAccount, amount: -amount, memo: nil)] : [ProposalPosting(id: UUID(), account: expenseAccount, amount: amount, memo: payee), ProposalPosting(id: UUID(), account: account, amount: -amount, memo: nil)]
        return TransactionProposal(id: UUID(), date: .now, payee: payee.isEmpty ? category : payee, note: text, currencyCode: "CNY", postings: postings, confidence: 0.82)
    }

    private static func accountName(in text: String) -> String {
        if text.contains("招行") { return "CMB" }
        if text.contains("建行") || text.contains("CCB") { return "CCB 1843" }
        if text.contains("农行") || text.contains("ABC") { return "ABC 0278" }
        if text.localizedCaseInsensitiveContains("huabei") || text.contains("花呗") { return "Huabei" }
        return "现金"
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
