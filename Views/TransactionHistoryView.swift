import SwiftUI
import SwiftData

struct TransactionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BookkeepingTransaction.date, order: .reverse) private var transactions: [BookkeepingTransaction]
    @State private var selected: BookkeepingTransaction?
    var body: some View {
        NavigationStack {
            List {
                ForEach(transactions) { transaction in
                    Button { selected = transaction } label: { TransactionRow(transaction: transaction) }.buttonStyle(.plain)
                }.onDelete { offsets in offsets.map { transactions[$0] }.forEach(modelContext.delete); try? modelContext.save() }
            }
            .navigationTitle("交易记录")
            .overlay { if transactions.isEmpty { ContentUnavailableView("暂无交易", systemImage: "tray", description: Text("点击记账添加第一笔交易")) } }
            .sheet(item: $selected) { TransactionDetailView(transaction: $0) }
        }
    }
}

struct TransactionRow: View {
    let transaction: BookkeepingTransaction
    var body: some View {
        HStack(spacing: 12) {
            GradientIcon(systemName: transaction.postings.first?.accountName.hasPrefix("Expenses:") == true ? "arrow.down.left" : "arrow.up.right", colors: [.cyan, .purple])
            VStack(alignment: .leading, spacing: 3) { Text(transaction.payee).font(.headline); Text(transaction.date, style: .date).font(.caption).foregroundStyle(.secondary) }
            Spacer(); Text(transaction.currencyCode).font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 5)
    }
}

struct TransactionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let transaction: BookkeepingTransaction
    var body: some View {
        NavigationStack { List { Section("交易") { LabeledContent("商户", value: transaction.payee); LabeledContent("日期", value: transaction.date.formatted(date: .abbreviated, time: .shortened)); if !transaction.note.isEmpty { LabeledContent("备注", value: transaction.note) } }; Section("分录") { ForEach(transaction.postings) { posting in HStack { Text(posting.accountName); Spacer(); Text(NSDecimalNumber(decimal: posting.amount).description).monospacedDigit() } } } }.navigationTitle("交易详情").toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } } }
    }
}
