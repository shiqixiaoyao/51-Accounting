import SwiftUI

struct TransactionRow: View {
    let transaction: BookkeepingTransaction

    private var primaryPosting: Posting? {
        transaction.postings.first
    }

    var body: some View {
        HStack(spacing: 12) {
            GradientIcon(systemName: "arrow.left.arrow.right", colors: [.cyan, .blue])
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.payee.isEmpty ? "未命名交易" : transaction.payee)
                    .font(.headline)
                    .lineLimit(1)
                Text(transaction.date, format: .dateTime.month().day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let primaryPosting {
                Text(NSDecimalNumber(decimal: primaryPosting.amount).stringValue)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(primaryPosting.amount >= 0 ? .green : .orange)
            }
        }
        .contentShape(Rectangle())
    }
}

struct TransactionDetailView: View {
    let transaction: BookkeepingTransaction

    var body: some View {
        NavigationStack {
            List {
                Section("交易信息") {
                    LabeledContent("商户", value: transaction.payee)
                    LabeledContent("日期", value: transaction.date.formatted(date: .long, time: .shortened))
                    if !transaction.note.isEmpty {
                        LabeledContent("备注", value: transaction.note)
                    }
                    LabeledContent("来源", value: transaction.source)
                }
                Section("分录") {
                    ForEach(transaction.postings) { posting in
                        HStack {
                            Text(posting.accountName)
                            Spacer()
                            Text(NSDecimalNumber(decimal: posting.amount).stringValue)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle("交易详情")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
