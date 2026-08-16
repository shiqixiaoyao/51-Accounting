import SwiftUI
import SwiftData

@MainActor
struct AddAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var accounts: [Account]

    @State private var type: AccountKind = .bankCard
    @State private var institution = ""
    @State private var lastFourDigits = ""
    @State private var currencyCode = "CNY"
    @State private var openingBalance = "0"
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("账户类型") {
                    Picker("类型", selection: $type) {
                        ForEach(AccountKind.allCases) { kind in
                            Label(kind.title, systemImage: kind.icon).tag(kind)
                        }
                    }
                }
                Section("账户信息") {
                    TextField(type.namePlaceholder, text: $institution)
                    if type.requiresLastFourDigits {
                        TextField("卡号后四位", text: $lastFourDigits)
                            .keyboardType(.numberPad)
                            .monospacedDigit()
                            .onChange(of: lastFourDigits) { _, value in
                                lastFourDigits = String(value.filter(\.isNumber).prefix(4))
                            }
                    }
                    TextField("币种代码", text: $currencyCode)
                        .textInputAutocapitalization(.characters)
                    TextField("期初余额", text: $openingBalance)
                        .keyboardType(.decimalPad)
                        .monospacedDigit()
                }
                Section("账本预览") {
                    Text(previewLedgerName)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("添加账户")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存", action: save).disabled(!canSave) }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var canSave: Bool {
        !institution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (!type.requiresLastFourDigits || lastFourDigits.count == 4)
    }

    private var previewLedgerName: String {
        Account.ledgerName(for: type.ledgerName(institution: institution, lastFourDigits: lastFourDigits), type: type.accountType)
    }

    private func save() {
        guard canSave, let amount = Decimal(string: openingBalance.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "请填写有效的账户名称、后四位和期初余额。"
            return
        }
        let normalizedName = type.displayName(institution: institution, lastFourDigits: lastFourDigits)
        guard !accounts.contains(where: { $0.displayName.caseInsensitiveCompare(normalizedName) == .orderedSame }) else {
            errorMessage = "该账户已存在。"
            return
        }
        modelContext.insert(Account(name: institution, type: type.accountType, currencyCode: currencyCode, openingBalance: amount, lastFourDigits: lastFourDigits))
        dismiss()
    }
}

enum AccountKind: String, CaseIterable, Identifiable {
    case bankCard, creditCard, wechat, alipay, huabei, jdBaitiao, cash

    var id: String { rawValue }
    var title: String {
        switch self {
        case .bankCard: return "银行卡"
        case .creditCard: return "信用卡"
        case .wechat: return "微信支付"
        case .alipay: return "支付宝"
        case .huabei: return "花呗"
        case .jdBaitiao: return "京东白条"
        case .cash: return "现金"
        }
    }
    var icon: String {
        switch self {
        case .bankCard: return "building.columns"
        case .creditCard: return "creditcard"
        case .wechat: return "message"
        case .alipay: return "a.square"
        case .huabei, .jdBaitiao: return "calendar.badge.clock"
        case .cash: return "banknote"
        }
    }
    var accountType: AccountType {
        switch self {
        case .creditCard, .huabei, .jdBaitiao: return .liability
        default: return .asset
        }
    }
    var requiresLastFourDigits: Bool { self == .bankCard || self == .creditCard }
    var namePlaceholder: String { requiresLastFourDigits ? "银行或发卡机构" : "账户名称" }
    func displayName(institution: String, lastFourDigits: String) -> String {
        let base = institution.trimmingCharacters(in: .whitespacesAndNewlines)
        return requiresLastFourDigits && !lastFourDigits.isEmpty ? "\(base) (\(lastFourDigits))" : base
    }
    func ledgerName(institution: String, lastFourDigits: String) -> String {
        switch self {
        case .bankCard: return "Bank:\(displayName(institution: institution, lastFourDigits: lastFourDigits))"
        case .creditCard: return "CreditCard:\(displayName(institution: institution, lastFourDigits: lastFourDigits))"
        case .wechat: return "Wallet:WeChat"
        case .alipay: return "Wallet:Alipay"
        case .huabei: return "PayLater:Huabei"
        case .jdBaitiao: return "PayLater:JDBaitiao"
        case .cash: return "Cash"
        }
    }
}
