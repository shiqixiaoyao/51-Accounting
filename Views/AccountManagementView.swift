import SwiftUI
import SwiftData

@MainActor
struct AccountManagementView: View {
    @State private var showingAddAccount = false
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    var body: some View {
        NavigationStack {
            List {
                if accounts.isEmpty {
                    ContentUnavailableView("暂无账户", systemImage: "building.columns", description: Text("点击右上角添加银行卡、信用卡、支付账户或现金。"))
                } else {
                    Section("账户") {
                        ForEach(accounts) { account in
                            NavigationLink {
                                AccountEditorView(account: account)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(account.selectionLabel)
                                    HStack {
                                        Text(account.ledgerName)
                                        Spacer()
                                        Text("¥ \(MoneyInput.display(account.openingBalance))").monospacedDigit()
                                    }
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("账户管理")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddAccount = true } label: {
                        Label("添加账户", systemImage: "plus")
                    }
                    .accessibilityLabel("添加账户")
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAddAccount) { AddAccountView() }
    }
}

@MainActor
private struct AccountEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \BookkeepingTransaction.date) private var transactions: [BookkeepingTransaction]

    let account: Account
    @State private var name: String
    @State private var type: AccountType
    @State private var currencyCode: String
    @State private var openingBalanceInput: String
    @State private var lastFourDigits: String
    @State private var errorMessage: String?
    @FocusState private var isOpeningBalanceFocused: Bool

    init(account: Account) {
        self.account = account
        _name = State(initialValue: account.name)
        _type = State(initialValue: account.type)
        _currencyCode = State(initialValue: account.currencyCode)
        _openingBalanceInput = State(initialValue: MoneyInput.display(account.openingBalance))
        _lastFourDigits = State(initialValue: account.lastFourDigits)
    }

    private var proposedLedgerName: String { Account.ledgerName(for: displayName, type: type) }
    private var displayName: String { lastFourDigits.isEmpty ? name : "\(name) (\(lastFourDigits))" }
    private var affectedPostingCount: Int { transactions.flatMap(\.postings).filter { $0.accountName == account.ledgerName }.count }

    var body: some View {
        Form {
            Section("账户信息") {
                TextField("银行或账户名称", text: $name)
                Picker("账户类型", selection: $type) {
                    ForEach(AccountType.allCases, id: \.self) { Text($0.chineseName).tag($0) }
                }
                if type == .asset || type == .liability {
                    TextField("卡号后四位（可选）", text: $lastFourDigits).keyboardType(.numberPad).monospacedDigit()
                        .onChange(of: lastFourDigits) { _, value in lastFourDigits = String(value.filter(\.isNumber).prefix(4)) }
                }
                TextField("币种代码", text: $currencyCode).textInputAutocapitalization(.characters)
                TextField("期初余额", text: $openingBalanceInput).keyboardType(.decimalPad).focused($isOpeningBalanceFocused).monospacedDigit()
            }
            Section("账本路径") {
                LabeledContent("当前路径") { Text(account.ledgerName).font(.footnote.monospaced()) }
                LabeledContent("保存后路径") { Text(proposedLedgerName).font(.footnote.monospaced()) }
                if proposedLedgerName != account.ledgerName { Text("保存后将同步更新 \(affectedPostingCount) 条历史分录的账本路径。").font(.footnote).foregroundStyle(.secondary) }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("编辑账户")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("保存", action: save) } }
        .onChange(of: isOpeningBalanceFocused) { _, focused in
            guard !focused, let value = try? AccountEditingRules.makeDraft(name: name, type: type, currencyCode: currencyCode, openingBalanceInput: openingBalanceInput, existingAccountNames: accounts.filter { $0.id != account.id }.map(\.name)).openingBalance else { return }
            openingBalanceInput = MoneyInput.display(value)
        }
    }

    private func save() {
        do {
            let draft = try AccountEditingRules.makeDraft(name: displayName, type: type, currencyCode: currencyCode, openingBalanceInput: openingBalanceInput, existingAccountNames: accounts.filter { $0.id != account.id }.map(\.name))
            try AccountEditingService.update(account: account, allAccounts: accounts, postings: transactions.flatMap(\.postings), draft: draft, in: modelContext)
            account.lastFourDigits = String(lastFourDigits.filter(\.isNumber).prefix(4))
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
