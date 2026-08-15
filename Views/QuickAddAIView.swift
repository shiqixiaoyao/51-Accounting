import SwiftUI
import SwiftData

struct QuickAddAIView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var manager = AIBookkeepingManager()
    @State private var text = ""
    @State private var proposal: TransactionProposal?
    @State private var errorMessage: String?
    @State private var savedMessage: String?
    let preferredProvider: AIProvider?

    init(preferredProvider: AIProvider? = nil) {
        self.preferredProvider = preferredProvider
    }

    private var activeProvider: AIProvider {
        preferredProvider ?? AIConfigurationStore.selectedProvider()
    }

    private var title: String {
        activeProvider == .poke ? "绯儿智能记账" : "\(activeProvider.rawValue) 智能记账"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(title).font(.largeTitle.bold())
                        Text("用自然语言描述收支，\(activeProvider.rawValue) 会生成需确认的平衡分录。请先在设置中完成 Endpoint、Model 与 API Key 的连接测试。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $text)
                            .frame(minHeight: 130)
                            .padding(8)
                            .background(.background, in: RoundedRectangle(cornerRadius: 12))

                        Button(action: parse) {
                            if manager.isLoading { HStack { ProgressView(); Text("正在解析") } }
                            else { Label("使用 \(activeProvider == .poke ? "绯儿" : activeProvider.rawValue) 生成待确认分录", systemImage: "sparkles") }
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.isLoading)

                        if let proposal {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("解析结果：\(proposal.payee)").font(.headline)
                                LabeledContent("置信度") { Text("\(Int((proposal.confidence * 100).rounded()))%").monospacedDigit() }
                                ForEach(proposal.postings) { posting in
                                    LabeledContent(posting.account) { Text("\(MoneyInput.display(posting.amount)) \(proposal.currencyCode)").monospacedDigit() }
                                }
                                Button("确认并保存") { save(proposal) }
                            }
                            .padding()
                            .background(.background, in: RoundedRectangle(cornerRadius: 14))
                        }

                        if let savedMessage { Text(savedMessage).foregroundStyle(.green) }
                        if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                    }
                    .padding()
                }
            }
            .navigationTitle("AI 记账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                NavigationLink { AIServiceSettingsView() } label: { Image(systemName: "slider.horizontal.3") }
            }
        }
    }

    private func parse() {
        errorMessage = nil
        savedMessage = nil
        proposal = nil
        Task {
            do { proposal = try await manager.parse(text: text, provider: preferredProvider) }
            catch { errorMessage = error.localizedDescription }
        }
    }

    private func save(_ proposal: TransactionProposal) {
        do {
            let postings = proposal.postings.map { Posting(accountName: $0.account, amount: $0.amount.roundedToCents, memo: $0.memo ?? "") }
            try TransactionService.create(date: proposal.date, payee: proposal.payee, note: proposal.note, currencyCode: proposal.currencyCode, source: "AI 记账 · \(activeProvider.rawValue)", postings: postings, in: modelContext)
            savedMessage = "AI 分录已保存到交易记录。"
            self.proposal = nil
            text = ""
        } catch { errorMessage = error.localizedDescription }
    }
}
