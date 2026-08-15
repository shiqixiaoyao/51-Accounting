import SwiftUI
import SwiftData

struct QuickAddAIView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var manager = AIBookkeepingManager()
    @State private var text = ""
    @State private var proposal: TransactionProposal?
    @State private var errorMessage: String?
    @State private var savedMessage: String?
    var body: some View { NavigationStack { ZStack { Color.black.ignoresSafeArea(); ScrollView { VStack(alignment: .leading, spacing: 18) { Text("和绯儿记账").font(.largeTitle.bold()); TextEditor(text: $text).frame(minHeight: 130); Button("让绯儿记下来", action: parse).disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.isLoading); if let proposal { VStack(alignment: .leading) { Text("我理解为：\(proposal.payee)").font(.headline); ForEach(proposal.postings) { Text("\($0.account)  \(NSDecimalNumber(decimal: $0.amount).stringValue) \(proposal.currencyCode)") }; Button("确认并保存") { save(proposal) } } }; if let savedMessage { Text(savedMessage).foregroundStyle(.green) }; if let errorMessage { Text(errorMessage).foregroundStyle(.red) } }.padding() } }.toolbar(.hidden, for: .navigationBar) } }
    private func parse() { errorMessage = nil; savedMessage = nil; Task { do { proposal = try await manager.parse(text: text) } catch { errorMessage = error.localizedDescription } } }
    private func save(_ proposal: TransactionProposal) { do { let postings = proposal.postings.map { Posting(accountName: $0.account, amount: $0.amount.roundedToCents, memo: $0.memo ?? "") }; try TransactionService.create(date: proposal.date, payee: proposal.payee, note: proposal.note, currencyCode: proposal.currencyCode, source: "绯儿（Poke）", postings: postings, in: modelContext); savedMessage = "绯儿：已经保存到交易记录啦。"; self.proposal = nil; text = "" } catch { errorMessage = error.localizedDescription } }
}
