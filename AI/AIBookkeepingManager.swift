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

    var defaultEndpoint: String {
        switch self {
        case .poke: return ""
        default: return ""
        }
    }
}

enum AIBookkeepingError: LocalizedError {
    case invalidResponse
    case unbalancedProposal

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "绯儿没有返回有效的记账结果，请检查接口设置后重试。"
        case .unbalancedProposal: return "绯儿生成的分录不平衡，未创建交易。"
        }
    }
}

@MainActor
final class AIBookkeepingManager: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var lastReply = ""

    var provider: AIProvider {
        get { AIProvider(rawValue: UserDefaults.standard.string(forKey: "aiProvider") ?? "") ?? .poke }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "aiProvider") }
    }

    var endpoint: URL? {
        let value = UserDefaults.standard.string(forKey: "aiEndpoint") ?? ""
        return URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var apiKey: String { UserDefaults.standard.string(forKey: "aiAPIKey") ?? "" }

    static let systemPrompt = """
    你是绯儿（Fei Er），Poke 的温柔、简洁、可靠的中文记账助手。直接帮助用户记账，不要假装是通用聊天机器人。
    用户常用账户包括：CCB 1843（建设银行）、ABC 0278（农业银行）、BGY 5980、Huabei（花呗）、现金；也要理解招行/CMB、建行/CCB、农行/ABC等别名，并优先匹配用户输入中的账户。
    使用完整复式记账规则：支出借记 Expenses:分类、贷记资产或负债账户；收入借记资产或负债账户、贷记 Income:分类；转账只在两个资产/负债账户之间移动。信用卡和花呗是负债，消费时贷记负债，偿还时借记负债、贷记付款账户；返现按用户语义正确记录，不要把负债消费误记成现金支出。
    所有金额使用 CNY，精确到小数点后两位，输出可保存的借贷平衡 Beancount 分录。无法确定账户时使用现金并在 note 中说明。返回 JSON TransactionProposal，不要返回 Markdown。
    """

    func parse(text: String) async throws -> TransactionProposal {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw AIBookkeepingError.invalidResponse }
        if endpoint != nil {
            return try await request(input: ["文本": input, "系统提示": Self.systemPrompt])
        }
        let proposal = try localParse(input)
        lastReply = "绯儿已经帮你整理好了，请确认这笔分录。"
        return proposal
    }

    func parse(imageData: Data, prompt: String = "请识别这张发票或收据，并生成中文记账交易。") async throws -> TransactionProposal {
        try await request(input: ["提示": "\(Self.systemPrompt)\n\(prompt)", "图片数据": imageData.base64EncodedString()])
    }

    private func localParse(_ text: String) throws -> TransactionProposal {
        let pattern = #"(?<![\d.])\d+(?:\.\d{1,2})?(?![\d.])"#
        guard let match = text.range(of: pattern, options: .regularExpression), let amount = Decimal(string: String(text[match])) else { throw AIBookkeepingError.invalidResponse }
        let account = Self.accountName(in: text)
        let payee = text.replacingOccurrences(of: String(text[match]), with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let category = text.contains("交通") || text.contains("打车") ? "交通" : text.contains("买") || text.contains("购物") ? "购物" : "餐饮"
        let isIncome = text.contains("工资") || text.contains("收入") || text.contains("返现")
        let counterpart = isIncome ? "Income:\(category)" : "Expenses:\(category)"
        let postings = isIncome ? [ProposalPosting(id: UUID(), account: account, amount: amount, memo: payee), ProposalPosting(id: UUID(), account: counterpart, amount: -amount, memo: nil)] : [ProposalPosting(id: UUID(), account: counterpart, amount: amount, memo: payee), ProposalPosting(id: UUID(), account: account, amount: -amount, memo: nil)]
        return TransactionProposal(id: UUID(), date: Date(), payee: payee.isEmpty ? category : payee, note: text, currencyCode: "CNY", postings: postings, confidence: 0.82)
    }

    private static func accountName(in text: String) -> String {
        if text.contains("招行") || text.localizedCaseInsensitiveContains("cmb") { return "CMB" }
        if text.contains("建行") || text.localizedCaseInsensitiveContains("ccb") { return "CCB 1843" }
        if text.contains("农行") || text.localizedCaseInsensitiveContains("abc") { return "ABC 0278" }
        if text.localizedCaseInsensitiveContains("huabei") || text.contains("花呗") { return "Huabei" }
        if text.contains("BGY") || text.contains("碧桂园") { return "BGY 5980" }
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
        request.httpBody = try JSONSerialization.data(withJSONObject: ["provider": provider.rawValue, "system": Self.systemPrompt, "input": input, "output_format": "TransactionProposal"])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else { throw AIBookkeepingError.invalidResponse }
        let proposal = try JSONDecoder().decode(TransactionProposal.self, from: data)
        guard proposal.postings.reduce(Decimal.zero, { $0 + $1.amount }) == 0 else { throw AIBookkeepingError.unbalancedProposal }
        lastReply = "绯儿已经解析完成，请确认后保存。"
        return proposal
    }
}
