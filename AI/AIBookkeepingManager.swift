import Foundation
import Combine

struct TransactionProposal: Codable, Identifiable { let id: UUID; var date: Date; var payee: String; var note: String; var currencyCode: String; var postings: [ProposalPosting]; var confidence: Double }
struct ProposalPosting: Codable, Identifiable { let id: UUID; var account: String; var amount: Decimal; var memo: String? }
enum AIProvider: String, Codable, CaseIterable { case poke = "Poke（绯儿 Fei Er）"; case openAICompatible = "OpenAI 兼容接口"; case deepSeek = "DeepSeek"; case claude = "Claude" }
enum AIBookkeepingError: LocalizedError { case invalidResponse; case unbalancedProposal; var errorDescription: String? { switch self { case .invalidResponse: return "绯儿没有返回有效的记账结果，请检查接口设置后重试。"; case .unbalancedProposal: return "绯儿生成的分录不平衡，未创建交易。" } } }
@MainActor final class AIBookkeepingManager: ObservableObject {
 @Published private(set) var isLoading = false; @Published private(set) var lastReply = ""
 var provider: AIProvider { get { AIProvider(rawValue: UserDefaults.standard.string(forKey: "aiProvider") ?? "") ?? .poke }; set { UserDefaults.standard.set(newValue.rawValue, forKey: "aiProvider") } }
 var endpoint: URL? { URL(string: (UserDefaults.standard.string(forKey: "aiEndpoint") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)) }
 var apiKey: String { KeychainStore.read("aiAPIKey") ?? "" }
 func parse(text: String) async throws -> TransactionProposal { let input = text.trimmingCharacters(in: .whitespacesAndNewlines); guard !input.isEmpty else { throw AIBookkeepingError.invalidResponse }; let proposal = try await request(input: ["文本": input]); guard proposal.postings.count >= 2, proposal.postings.allSatisfy({ $0.amount == $0.amount.roundedToCents }), proposal.postings.reduce(Decimal.zero) { $0 + $1.amount }.roundedToCents == 0 else { throw AIBookkeepingError.unbalancedProposal }; lastReply = "绯儿已经整理好了，请确认这笔分录。"; return proposal }
 private func request(input: [String: String]) async throws -> TransactionProposal { guard let endpoint else { throw URLError(.badURL) }; isLoading = true; defer { isLoading = false }; var request = URLRequest(url: endpoint, timeoutInterval: 30); request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.setValue("application/json", forHTTPHeaderField: "Accept"); if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }; request.httpBody = try JSONSerialization.data(withJSONObject: ["provider": provider.rawValue, "input": input]); let (data, response) = try await URLSession.shared.data(for: request); guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw AIBookkeepingError.invalidResponse }; return try JSONDecoder().decode(TransactionProposal.self, from: data) }
}
