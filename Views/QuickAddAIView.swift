import SwiftUI

/// 中文 AI 快速记账页面。
struct QuickAddAIView: View {
    @StateObject private var manager = AIBookkeepingManager()
    @State private var text = ""
    @State private var proposal: TransactionProposal?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("自然语言记账") {
                    TextEditor(text: $text).frame(minHeight: 120).overlay(alignment: .topLeading) { if text.isEmpty { Text("例如：昨天用信用卡买咖啡 32 元").foregroundStyle(.secondary).padding(8) } }
                    Button { Task { do { proposal = try await manager.parse(text: text) } catch { errorMessage = error.localizedDescription } } } label: { Label(manager.isLoading ? "正在解析…" : "AI 解析", systemImage: "sparkles") }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.isLoading)
                }
                if let proposal { Section("确认账单") { Text("商户：\(proposal.payee)"); ForEach(proposal.postings) { posting in Text("\(posting.account)：\(posting.amount.description) \(proposal.currencyCode)") }; Text("置信度：\(Int(proposal.confidence * 100))%") } }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }.navigationTitle("快速记账")
        }
    }
}
