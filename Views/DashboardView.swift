import SwiftUI
import SwiftData

struct DashboardView: View {
    @Binding var showingAdd: Bool
    @Query(sort: \BookkeepingTransaction.date, order: .reverse) private var transactions: [BookkeepingTransaction]
    @Query private var accounts: [Account]
    init(showingAdd: Binding<Bool> = .constant(false)) { _showingAdd = showingAdd }
    private var balance: Decimal { accounts.reduce(Decimal.zero) { $0 + $1.openingBalance } }
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.black.ignoresSafeArea(); LinearGradient(colors: [.cyan.opacity(0.16), .blue.opacity(0.08), .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                ScrollView(showsIndicators: false) { VStack(alignment: .leading, spacing: 18) { header; summaryCard; accountsCard; transactionsCard }.padding(18) }
                Button { showingAdd = true } label: { Image(systemName: "plus").font(.title2.weight(.bold)).foregroundStyle(.black).frame(width: 60, height: 60).background(LinearGradient(colors: [.cyan, .mint], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle()).shadow(color: .cyan.opacity(0.35), radius: 16, y: 8) }.padding(24)
            }.toolbar(.hidden, for: .navigationBar)
        }
    }
    private var header: some View { HStack(alignment: .bottom) { VStack(alignment: .leading, spacing: 5) { Text("你好，今天").font(.subheadline.weight(.medium)).foregroundStyle(.secondary); Text("51 记账").font(.system(size: 34, weight: .bold, design: .rounded)) }; Spacer(); Image(systemName: "waveform.path.ecg").font(.title2.weight(.semibold)).foregroundStyle(.cyan).padding(12).background(.ultraThinMaterial, in: Circle()) } }
    private var summaryCard: some View { GlassCard(tint: .cyan) { VStack(alignment: .leading, spacing: 18) { Label("总资产概览", systemImage: "chart.line.uptrend.xyaxis").foregroundStyle(.secondary); Text("¥\(NSDecimalNumber(decimal: balance).description)").font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit()); Label("保持良好的记账习惯", systemImage: "arrow.up.right").font(.caption).foregroundStyle(.green) } } }
    private var accountsCard: some View { GlassCard(tint: .purple) { VStack(alignment: .leading, spacing: 14) { Label("账户", systemImage: "wallet.pass.fill").font(.headline).foregroundStyle(.purple); if accounts.isEmpty { Text("默认账户可直接用于记账").foregroundStyle(.secondary) } else { ForEach(accounts.prefix(3)) { account in HStack { GradientIcon(systemName: account.isLiability ? "creditcard.fill" : "building.columns.fill", colors: [.purple, .cyan]); Text(account.name); Spacer(); Text(NSDecimalNumber(decimal: account.openingBalance).description).monospacedDigit() } } } } } }
    private var transactionsCard: some View { GlassCard(tint: .orange) { VStack(alignment: .leading, spacing: 14) { Label("最近交易", systemImage: "clock.arrow.circlepath").font(.headline).foregroundStyle(.orange); if transactions.isEmpty { Text("点击右下角 + 添加第一笔交易").foregroundStyle(.secondary) } else { ForEach(transactions.prefix(5)) { TransactionRow(transaction: $0) } } } } }
}
