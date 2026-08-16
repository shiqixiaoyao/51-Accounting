import SwiftUI
import SwiftData

struct DashboardView: View {
    @State private var showingAIAdd = false
    @Query(sort: \BookkeepingTransaction.date, order: .reverse) private var transactions: [BookkeepingTransaction]
    @Query private var accounts: [Account]

    private var totalAssets: Decimal {
        BalanceCalculator.totalAssets(accounts: accounts, transactions: transactions)
    }

    private var totalLiabilities: Decimal {
        BalanceCalculator.totalLiabilities(accounts: accounts, transactions: transactions)
    }

    private var netAssets: Decimal {
        BalanceCalculator.netAssets(accounts: accounts, transactions: transactions)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop(accent: .cyan)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        summaryCard
                        accountsCard
                        transactionsCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("财务概览")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAIAdd = true } label: {
                        Image(systemName: "sparkles")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.cyan)
                    }
                    .accessibilityLabel("AI 记账")
                }
            }
        }
        .sheet(isPresented: $showingAIAdd) { QuickAddAIView() }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("财务概览")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.cyan)
                Text("今天也记得记一笔")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            GradientIcon(systemName: "waveform.path.ecg", colors: [.cyan, .mint])
        }
    }

    private var summaryCard: some View {
        GlassCard(tint: .cyan) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("净资产", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("实时计算")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.cyan.opacity(0.14), in: Capsule())
                }
                Text("¥\(MoneyInput.display(netAssets))")
                    .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.72)
                HStack(spacing: 12) {
                    summaryMetric(title: "资产", amount: totalAssets, tint: .mint)
                    summaryMetric(title: "负债", amount: totalLiabilities, tint: .orange)
                }
            }
        }
    }

    private func summaryMetric(title: String, amount: Decimal, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("¥\(MoneyInput.display(amount))")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var accountsCard: some View {
        GlassCard(tint: .indigo) {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle(
                    "账户余额",
                    icon: "wallet.pass.fill",
                    tint: .indigo,
                    trailing: accounts.isEmpty ? nil : "\(accounts.count) 个账户"
                )
                if accounts.isEmpty {
                    emptyLine("还没有账户，记账时可直接添加第一个账户。", icon: "wallet.pass")
                } else {
                    ForEach(accounts.prefix(3)) { account in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(.indigo.opacity(0.78))
                                .frame(width: 7, height: 7)
                            Text(account.selectionLabel).lineLimit(1)
                            Spacer()
                            Text("¥\(MoneyInput.display(BalanceCalculator.balance(for: account, transactions: transactions)))")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                        }
                    }
                }
            }
        }
    }

    private var transactionsCard: some View {
        GlassCard(tint: .orange) {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle(
                    "全部交易记录",
                    icon: "clock.arrow.circlepath",
                    tint: .orange,
                    trailing: transactions.isEmpty ? nil : "\(transactions.count) 笔"
                )
                if transactions.isEmpty {
                    emptyLine("从“记一笔”开始，让账本有第一条记录。", icon: "square.and.pencil")
                } else {
                    ForEach(transactions) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String, icon: String, tint: Color, trailing: String?) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(tint)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func emptyLine(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
    }
}
