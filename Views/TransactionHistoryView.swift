import SwiftUI
import SwiftData

struct TransactionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BookkeepingTransaction.date, order: .reverse) private var transactions: [BookkeepingTransaction]
    @State private var selected: BookkeepingTransaction?
    @State private var errorMessage: String?
    var body: some View { NavigationStack { List { ForEach(transactions) { Button { selected = $0 } label: { TransactionRow(transaction: $0) }.buttonStyle(.plain) }.onDelete(perform: delete) }.navigationTitle("交易记录").overlay { if transactions.isEmpty { ContentUnavailableView("暂无交易", systemImage: "tray") } }.sheet(item: $selected) { TransactionDetailView(transaction: $0) }.alert("删除失败", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("确定") {} } message: { Text(errorMessage ?? "") } } }
    private func delete(at offsets: IndexSet) { do { offsets.map { transactions[$0] }.forEach(modelContext.delete); try modelContext.save() } catch { errorMessage = error.localizedDescription } }
}
