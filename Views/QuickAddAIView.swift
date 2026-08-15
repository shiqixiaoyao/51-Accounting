import SwiftUI
import SwiftData

struct QuickAddAIView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var manager = AIBookkeepingManager()
    @State private var text = ""
    @State private var proposal: TransactionProposal?
    @State private var errorMessage: String?
    @State private var savedMessage: String?

    private var beancountPreview: String {
        guard let proposal else { return "" }
        let date = proposal.date.formatted(.iso8601.year().month().day())
        let lines = proposal.postings.map { "    \($0.account)  \(NSDecimalNumber(decimal: $0.amount.roundedToCents).stringValue) \(proposal.currencyCode)" }.joined(separator: "\n")
        return "\(date) * \(proposal.payee)\n\(lines)"
    }

    var body: some View {
        NavigationStack { ZStack { Color.black.ignoresSafeArea(); LinearGradient(colors: [.purple.opacity(0.16), .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea(); ScrollView { VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) { VStack(alignment: .leading, spacing: 5) { Text("和绯儿记账").font(.system(size: 34, weight: .bold, design: .rounded)); Text("告诉绯儿发生了什么，她会帮你整理好分录").foregroundStyle(.secondary) }; Spacer(); Image(systemName: "sparkles").foregroundStyle(.purple).font(.title2) }
            GlassCard(tint: .purple) { VStack(alignment: .leading, spacing: 14) { Label("绯儿", systemImage: "bubble.left.and.bubble.right.fill").font(.headline.weight(.bold)).foregroundStyle(.purple); TextEditor(text: $text).scrollContentBackground(.hidden).frame(minHeight: 120).padding(10).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous)).overlay(alignment: .topLeading) { if text.isEmpty { Text("例如：美团外卖 35.50 招行").foregroundStyle(.secondary).padding(18) } }; Button { parse() } label: { Label(manager.isLoading ? "绯儿正在整理…" : "让绯儿记下来", systemImage: manager.isLoading ? "hourglass" : "sparkles").frame(maxWidth: .infinity).padding(.vertical, 4) }.buttonStyle(.borderedProminent).tint(.purple).disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.isLoading) } }
            if let proposal { GlassCard(tint: .green) { VStack(alignment: .leading, spacing: 12) { Label("绯儿的记账建议", systemImage: "checkmark.seal.fill").font(.headline.weight(.bold)).foregroundStyle(.green); Text("我理解为：\(proposal.payee)").font(.title3.weight(.bold)); ForEach(proposal.postings) { posting in HStack { Text(posting.account); Spacer(); Text("\(NSDecimalNumber(decimal: posting.amount).stringValue) \(proposal.currencyCode)").monospacedDigit() }.font(.subheadline) }; Text("置信度 \(Int(proposal.confidence * 100))% · 请确认账户和金额").font(.caption).foregroundStyle(.secondary); Text(beancountPreview).font(.system(.caption, design: .monospaced)).textSelection(.enabled).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14)); Button("确认并保存") { save(proposal) }.buttonStyle(.borderedProminent).tint(.green) } } }
            if let savedMessage { Label(savedMessage, systemImage: "checkmark.circle.fill").foregroundStyle(.green) }; if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red) }
        }.padding(18) } }.toolbar(.hidden, for: .navigationBar) }
    }
    private func parse() { errorMessage = nil; savedMessage = nil; Task { do { proposal = try await manager.parse(text: text) } catch { errorMessage = error.localizedDescription } } }
    private func save(_ proposal: TransactionProposal) {
        let postings = proposal.postings.map { Posting(accountName: $0.account, amount: $0.amount.roundedToCents, memo: $0.memo ?? "") }
        switch TransactionValidator.validate(postings: postings) {
        case .failure(let error): errorMessage = error.localizedDescription
        case .success:
            let transaction = BookkeepingTransaction(date: proposal.date, payee: proposal.payee, note: proposal.note, currencyCode: proposal.currencyCode, source: "绯儿（Poke）", postings: postings)
            modelContext.insert(transaction)
            do { try modelContext.save(); savedMessage = "绯儿：已经保存到交易记录啦。"; self.proposal = nil; text = "" } catch { errorMessage = "保存失败，请稍后重试：\(error.localizedDescription)" }
        }
    }
}
