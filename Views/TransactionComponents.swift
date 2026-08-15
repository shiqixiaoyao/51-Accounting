import SwiftUI

struct TransactionRow: View {
    let transaction: BookkeepingTransaction

    private var primaryPosting: Posting? { transaction.postings.first }

    var body: some View {
        HStack(spacing: 12) {
            GradientIcon(systemName: "arrow.left.arrow.right", colors: amountColorPair)
            VStack(alignment: .leading, spacing: 5) {
                Text(transaction.payee.isEmpty ? "未命名交易" : transaction.payee)
                    .font(.headline).lineLimit(1)
                HStack(spacing: 6) {
                    Text(transaction.date, format: .dateTime.month().day())
                    Text("·")
                    Text(transaction.source)
                }
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 10)
            if let primaryPosting {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(primaryPosting.amount >= 0 ? "+" : "")¥\(MoneyInput.display(primaryPosting.amount))")
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(primaryPosting.amount >= 0 ? .mint : .orange)
                    Text(primaryPosting.amount >= 0 ? "流入" : "流出")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var amountColorPair: [Color] {
        guard let primaryPosting else { return [.cyan, .blue] }
        return primaryPosting.amount >= 0 ? [.mint, .cyan] : [.orange, .pink]
    }
}

struct TransactionDetailView: View {
    let transaction: BookkeepingTransaction

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(transaction.payee.isEmpty ? "未命名交易" : transaction.payee).font(.title3.bold())
                        Text(transaction.date.formatted(date: .long, time: .shortened)).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                Section("交易信息") {
                    LabeledContent("来源", value: transaction.source)
                    if !transaction.note.isEmpty { LabeledContent("备注", value: transaction.note) }
                }
                Section("平衡分录") {
                    ForEach(transaction.postings) { posting in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(posting.accountName).font(.subheadline.weight(.medium))
                                Text(posting.amount >= 0 ? "借方 / 流入" : "贷方 / 流出")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(posting.amount >= 0 ? "+" : "")¥\(MoneyInput.display(posting.amount))")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(posting.amount >= 0 ? .mint : .orange)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("交易详情")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
