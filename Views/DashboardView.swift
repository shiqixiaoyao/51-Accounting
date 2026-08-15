import SwiftUI
import SwiftData

/// 中文账务概览页面。
struct DashboardView: View {
    @Query(sort: \BookkeepingTransaction.date, order: .reverse) private var transactions: [BookkeepingTransaction]

    init() {}

    var body: some View {
        NavigationStack {
            List {
                Section("最近交易") {
                    ForEach(transactions.prefix(20)) { transaction in
                        VStack(alignment: .leading) {
                            Text(transaction.payee).font(.headline)
                            Text(transaction.date, style: .date).foregroundStyle(.secondary)
                            Text(transaction.note).font(.caption)
                        }
                    }
                }
            }
            .overlay {
                if transactions.isEmpty {
                    ContentUnavailableView("暂无交易", systemImage: "tray", description: Text("使用快速记账添加第一笔交易"))
                }
            }
            .navigationTitle("51 记账")
        }
    }
}
