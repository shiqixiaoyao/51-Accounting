import SwiftUI
import SwiftData

struct DashboardView: View {
    @Binding var showingAdd: Bool
    @Query(sort: \\BookkeepingTransaction.date, order: .reverse) private var transactions: [BookkeepingTransaction]
    @Query private var accounts: [Account]
    init(showingAdd: Binding<Bool> = .constant(false)) { _showingAdd = showingAdd }
    private var totalAssets: Decimal { TransactionService.totalAssets(accounts: accounts, transactions: transactions) }
    private var totalLiabilities: Decimal { TransactionService.totalLiabilities(accounts: accounts, transactions: transactions) }
    private var netAssets: Decimal { TransactionService.netAssets(accounts: accounts, transactions: transactions) }
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.black.ignoresSafeArea(); LinearGradient(colors: [.cyan.opacity(0.16), .blue.opacity(0.08), .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                ScrollView(showsIndicators: false) { VStack(alignment: .leading, spacing: 18) { header; summaryCard; accountsCard; transactionsCard }.padding(18) }
                Button { showingAdd = true } label: { Image(systemName: "plus").font(.title2.weight(.bold)).foregroundStyle(.black).frame(width: 60, height: 60).background(LinearGradient(colors: [.cyan, .mint], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle()).shadow(color: .cyan.opacity(0.35), radius: 16, y: 8) }.padding(24)
            }.toolbar(.hidden, for: .navigationBar)
        }
    }
    private var header: some View { HStack(alignment: .bottom) { VStack(alignment: .leading, spacing: 5) { Text("今天也记得记一笔").font(.subheadline.weight(.medium)).foregroundStyle(.secondary); Text("51 账本").font(.system(size: 34, weight: .bold, design: .rounded)) }; Spacer(); Image(systemName: "waveform.path.ecg").font(.title2.weight(.semibold)).foregroundStyle(.cyan).padding(12).background(.ultraThinMaterial, in: Circle()) } }
    private var summaryCard: some View { GlassCard(tint: .cyan) { VStack(alignment: .leading, spacing: 14) { Label("净资产", systemImage: "chart.line.uptrend.xyaxis").foregroundStyle(.secondary); Text("¥\(NSDecimalNumber(decimal: netAssets).stringValue)").font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit()); HStack { Text("资产 ¥\(NSDecimalNumber(decimal: totalAssets).stringValue)"); Spacer(); Text("负债 ¥\(NSDecimalNumber(decimal: totalLiabilities).stringValue)") }.font(.caption.monospacedDigit()).foregroundStyle(.secondary) } } }
    private var accountsCard: some View { GlassCard(tint: .purple) { VStack(alignment: .leading, spacing: 14) { Label("账户余额", systemImage: "wallet.pass.fill").font(.headline).foregroundStyle(.purple); if accounts.isEmpty { Text("添加账户后，即可在这里查看余额").foregroundStyle(.secondary) } else { ForEach(accounts.prefix(3)) { account in HStack { GradientIcon(systemName: account.isLiability ? "creditcard.fill" : "building.columns.fill", colors: [.purple, .cyan]); Text(account.name); Spacer(); Text(NSDecimalNumber(decimal: TransactionService.balance(for: account, transactions: transactions)).stringValue).monospacedDigit() } } } } } }
    private var transactionsCard: some View { GlassCard(tint: .orange) { VStack(alignment: .leading, spacing: 14) { Label("最近记账", systemImage: "clock.arrow.circlepath").font(.headline).foregroundStyle(.orange); if transactions.isEmpty { Text("点击右下角“＋”，记录第一笔交易").foregroundStyle(.secondary) } else { ForEach(transactions.prefix(5)) { TransactionRow(transaction: $0) } } } } }
}
