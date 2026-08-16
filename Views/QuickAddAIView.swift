import SwiftUI
import SwiftData

struct QuickAddAIView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool
    @StateObject private var manager = AIBookkeepingManager()
    @State private var text = ""
    @State private var proposal: TransactionProposal?
    @State private var errorMessage: String?
    @State private var savedMessage: String?
    let preferredProvider: AIProvider?

    init(preferredProvider: AIProvider? = nil) { self.preferredProvider = preferredProvider }

    private var activeProvider: AIProvider { preferredProvider ?? AIConfigurationStore.selectedProvider() }
    private var title: String { activeProvider == .poke ? "绯儿智能记账" : "\(activeProvider.rawValue) 智能记账" }
    private var canParse: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !manager.isLoading }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop(accent: .cyan)
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { isInputFocused = false }
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        inputCard
                        if let proposal { proposalCard(proposal) }
                        if let savedMessage { InlineStatusCard(text: savedMessage, systemImage: "checkmark.circle.fill", tint: .mint) }
                        if let errorMessage { InlineStatusCard(text: errorMessage, systemImage: "exclamationmark.triangle.fill", tint: .red) }
                    }
                    .padding(18)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("AI 记账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismissFlow() }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink { AIServiceSettingsView() } label: { Image(systemName: "slider.horizontal.3") }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 30, weight: .bold, design: .rounded))
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars").foregroundStyle(.cyan)
                Text("描述收支，预览平衡分录，再确认写入账本。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Text(activeProvider.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.cyan)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.cyan.opacity(0.13), in: Capsule())
        }
    }

    private var inputCard: some View {
        GlassCard(tint: .cyan) {
            VStack(alignment: .leading, spacing: 14) {
                Label("用一句话描述", systemImage: "text.bubble.fill").font(.headline)
                TextEditor(text: $text)
                    .focused($isInputFocused)
                    .frame(minHeight: 132)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1) }
                Text("例如：午餐 36.50 元，用建行卡支付。").font(.footnote).foregroundStyle(.secondary)
                examplePrompts
                PrimaryActionButton(
                    title: manager.isLoading ? "正在解析" : "生成待确认分录",
                    systemImage: manager.isLoading ? "hourglass" : "sparkles",
                    isDisabled: !canParse,
                    action: parse
                )
            }
        }
    }

    private var examplePrompts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(["午餐 36.50 元，用建行卡支付", "收到工资 12,000 元，存入工资卡", "从建行转 500 元到支付宝"], id: \.self) { example in
                    Button(example) { text = example }
                        .font(.caption).foregroundStyle(.cyan)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(.cyan.opacity(0.10), in: Capsule())
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func proposalCard(_ proposal: TransactionProposal) -> some View {
        GlassCard(tint: .mint) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("待确认分录", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(.mint)
                    Spacer()
                    Text("置信度 \(Int((proposal.confidence * 100).rounded()))%")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                Text(proposal.payee).font(.title3.weight(.bold))
                VStack(spacing: 0) {
                    ForEach(Array(proposal.postings.enumerated()), id: \.element.id) { index, posting in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(posting.account).font(.subheadline).lineLimit(1)
                            Spacer()
                            Text("\(posting.amount >= 0 ? "+" : "")\(MoneyInput.display(posting.amount)) \(proposal.currencyCode)")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(posting.amount >= 0 ? .mint : .orange)
                        }
                        .padding(.vertical, 10)
                        if index < proposal.postings.count - 1 { Divider().overlay(.white.opacity(0.10)) }
                    }
                }
                Text("分录已通过金额平衡与两位小数校验。确认后将写入账本。")
                    .font(.footnote).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button("重新输入") { resetForReinput() }
                        .buttonStyle(.bordered)
                        .tint(.cyan)
                    Button("清空") { clearInput() }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    Button("确认保存") { save(proposal) }
                        .buttonStyle(.borderedProminent)
                        .tint(.mint)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func parse() {
        isInputFocused = false
        errorMessage = nil
        savedMessage = nil
        proposal = nil
        Task {
            do { proposal = try await manager.parse(text: text, provider: preferredProvider) }
            catch { errorMessage = error.localizedDescription }
        }
    }

    private func resetForReinput() {
        proposal = nil
        errorMessage = nil
        savedMessage = nil
        Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            isInputFocused = true
        }
    }

    private func clearInput() {
        isInputFocused = false
        text = ""
        proposal = nil
        errorMessage = nil
        savedMessage = nil
    }

    private func dismissFlow() {
        isInputFocused = false
        dismiss()
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
