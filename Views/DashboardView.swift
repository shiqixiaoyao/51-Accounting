import SwiftUI
import SwiftData

/// 账务概览：摘要、账户概况与最近交易。
struct DashboardView: View {
    @Query(sort: \\BookkeepingTransaction.date, order: .reverse) private var transactions: [BookkeepingTransaction]
    @Query private var accounts: [Account]

    init() {}

    private var balance: Decimal {
        accounts.reduce(Decimal.zero) { $0 + $1.openingBalance }
    }

    private var balanceText: String {
        NSDecimalNumber(decimal: balance).description(withLocale: Locale(identifier: "zh_CN"))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                LinearGradient(colors: [.cyan.opacity(0.16), .blue.opacity(0.08), .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        summaryCard
                        accountsCard
                        transactionsCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text("你好，今天")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("51 记账")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
            }
            Spacer()
            Image(systemName: "waveform.path.ecg")
                .symbolRenderingMode(.hierarchical)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.cyan)
                .padding(12)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    private var summaryCard: some View {
        GlassCard(tint: .cyan) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label("总资产概览", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("本月")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.cyan.opacity(0.14), in: Capsule())
                }
                Text("¥\(balanceText)")
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right")
                    Text("保持良好的记账习惯")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
            }
        }
    }

    private var accountsCard: some View {
        GlassCard(tint: .purple) {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("账户", icon: "wallet.pass.fill", color: .purple)
                if accounts.isEmpty {
                    Text("添加账户后，这里会显示资产概况")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(accounts.prefix(3)) { account in
                        HStack(spacing: 12) {
                            GradientIcon(systemName: account.isLiability ? "creditcard.fill" : "building.columns.fill", colors: account.isLiability ? [.orange, .red] : [.purple, .cyan])
                            VStack(alignment: .leading, spacing: 3) {
                                Text(account.name).font(.subheadline.weight(.semibold))
                                Text(account.currencyCode).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(NSDecimalNumber(decimal: account.openingBalance).description)
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
                sectionTitle("最近交易", icon: "clock.arrow.circlepath", color: .orange)
                if transactions.isEmpty {
                    ContentUnavailableView("暂无交易", systemImage: "tray", description: Text("使用 AI 快速记账添加第一笔交易"))
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(transactions.prefix(5)) { transaction in
                        HStack(spacing: 12) {
                            GradientIcon(systemName: "arrow.down.left", colors: [.orange, .pink])
                            VStack(alignment: .leading, spacing: 3) {
                                Text(transaction.payee).font(.subheadline.weight(.semibold))
                                Text(transaction.date, style: .date).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(transaction.currencyCode).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.headline.weight(.bold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
    }
}
