import SwiftUI

/// 中文 AI 快速记账页面。
struct QuickAddAIView: View {
    @StateObject private var manager = AIBookkeepingManager()
    @State private var text = ""
    @State private var proposal: TransactionProposal?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                LinearGradient(colors: [.purple.opacity(0.16), .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("快速记账").font(.system(size: 34, weight: .bold, design: .rounded))
                            Text("用一句话记录每一笔生活开销").foregroundStyle(.secondary)
                        }
                        GlassCard(tint: .purple) {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("自然语言记账", systemImage: "wand.and.stars")
                                    .font(.headline.weight(.bold)).foregroundStyle(.purple)
                                TextEditor(text: $text)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 120)
                                    .padding(10)
                                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(alignment: .topLeading) {
                                        if text.isEmpty { Text("例如：昨天用信用卡买咖啡 32 元").foregroundStyle(.secondary).padding(18) }
                                    }
                                Button {
                                    Task {
                                        do { proposal = try await manager.parse(text: text) }
                                        catch { errorMessage = error.localizedDescription }
                                    }
                                } label: {
                                    Label(manager.isLoading ? "正在解析…" : "AI 解析", systemImage: manager.isLoading ? "hourglass" : "sparkles")
                                        .frame(maxWidth: .infinity).padding(.vertical, 4)
                                }
                                .buttonStyle(.borderedProminent).tint(.purple)
                                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.isLoading)
                            }
                        }
                        if let proposal {
                            GlassCard(tint: .green) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label("确认账单", systemImage: "checkmark.seal.fill").font(.headline.weight(.bold)).foregroundStyle(.green)
                                    Text(proposal.payee).font(.title3.weight(.bold))
                                    ForEach(proposal.postings) { posting in
                                        HStack { Text(posting.account); Spacer(); Text("\(posting.amount.description) \(proposal.currencyCode)").monospacedDigit() }
                                            .font(.subheadline)
                                    }
                                    Text("置信度 \(Int(proposal.confidence * 100))%").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red) }
                    }
                    .padding(18)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
