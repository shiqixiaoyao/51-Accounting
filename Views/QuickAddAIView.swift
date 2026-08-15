import SwiftUI
import SwiftData

struct QuickAddAIView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var manager = AIBookkeepingManager()
    @State private var text = ""
    @State private var proposal: TransactionProposal?
    @State private var errorMessage: String?
    @State private var savedMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("AI 智能记账")
                            .font(.largeTitle.bold())
                        Text("用自然语言描述收支，AI 会生成需确认的平衡分录。请先在设置中完成 AI 服务连接测试。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $text)
                            .frame(minHeight: 130)
                            .padding(8)
                            .background(.background, in: RoundedRectangle(cornerRadius: 12))

                        Button(action: parse) {
                            if manager.isLoading {
                                HStack { ProgressView(); Text("正在解析") }
                            } else {
                                Label("生成待确认分录", systemImage: "sparkles")
                            }
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.isLoading)

                        if let proposal {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("解析结果：\(proposal.payee)")
                                    .font(.headline)
                                LabeledContent("置信度") {
                                    Text("\(Int((proposal.confidence * 100).rounded()))%")
                                        .monospacedDigit()
                                }
                                ForEach(proposal.postings) { posting in
                                    LabeledContent(posting.account) {
                                        Text("\(MoneyInput.display(posting.amount)) \(proposal.currencyCode)")
                                            .monospacedDigit()
                                    }
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
        }
    }

    private func parse() {
        errorMessage = nil
        savedMessage = nil
        proposal = nil
        Task {
            do {
                proposal = try await manager.parse(text: text)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func save(_ proposal: TransactionProposal) {
        do {
            let postings = proposal.postings.map {
                Posting(accountName: $0.account, amount: $0.amount.roundedToCents, memo: $0.memo ?? "")
            }
            try TransactionService.create(
                date: proposal.date,
                payee: proposal.payee,
                note: proposal.note,
                currencyCode: proposal.currencyCode,
                source: "AI 记账",
                postings: postings,
                in: modelContext
            )
            savedMessage = "AI 分录已保存到交易记录。"
            self.proposal = nil
            text = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
