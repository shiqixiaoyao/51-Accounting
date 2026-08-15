import SwiftUI
import SwiftData

enum TransactionEntryType: String, CaseIterable, Identifiable { case expense = "支出", income = "收入", transfer = "转账"; var id: String { rawValue } }

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @State private var type: TransactionEntryType = .expense
    @State private var amount = ""
    @State private var account = ""
    @State private var destination = ""
    @State private var payee = ""
    @State private var category = "餐饮"
    @State private var note = ""
    @State private var date = Date()
    @State private var errorMessage: String?
    @State private var isAccountCreatorPresented = false
    @State private var accountCreationTarget: AccountCreationTarget = .source
    @State private var newAccountName = ""
    @State private var newAccountType: AccountType = .asset
    @State private var newAccountCurrency = "CNY"
    @State private var accountCreationError: String?
    private let categories = ["餐饮", "交通", "购物", "居住", "娱乐", "其他"]
    private var accountOptions: [String] { accounts.map(\.name).sorted() }
    private var value: Decimal? { Decimal(string: amount.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX")) }
    private var canSave: Bool {
        guard let value else { return false }
        return value > 0 && !account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (type != .transfer || !destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("类型", selection: $type) {
                        ForEach(TransactionEntryType.allCases) { entryType in
                            Text(entryType.rawValue).tag(entryType)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("金额") {
                    HStack {
                        Text("¥")
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("账户") {
                    Picker(type == .transfer ? "转出账户" : "账户", selection: $account) {
                        Text("请选择账户").tag("")
                        ForEach(accountOptions, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }

                    Button {
                        presentAccountCreator(for: .source)
                    } label: {
                        Label(type == .transfer ? "新增转出账户" : "新增账户", systemImage: "plus.circle")
                    }

                    if type == .transfer {
                        Picker("转入账户", selection: $destination) {
                            Text("请选择账户").tag("")
                            ForEach(accountOptions.filter { $0 != account }, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }

                        Button {
                            presentAccountCreator(for: .destination)
                        } label: {
                            Label("新增转入账户", systemImage: "plus.circle")
                        }
                    }

                    if accounts.isEmpty {
                        Text("还没有账户。请先新增一个账户再保存交易。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("详情") {
                    TextField("商户 / 收入来源", text: $payee)
                    Picker("分类", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    TextField("备注（可选）", text: $note)
                    DatePicker("日期", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("保存交易", action: save)
                        .disabled(!canSave)
                }
            }
            .navigationTitle("新增记账")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $isAccountCreatorPresented) {
            accountCreator
        }
    }

    private var accountCreator: some View {
        NavigationStack {
            Form {
                Section("账户信息") {
                    TextField("账户名称", text: $newAccountName)
                    Picker("账户类型", selection: $newAccountType) {
                        ForEach(AccountType.allCases, id: \.self) { accountType in
                            Text(accountType.chineseName).tag(accountType)
                        }
                    }
                    TextField("币种代码", text: $newAccountCurrency)
                        .textInputAutocapitalization(.characters)
                }

                if let accountCreationError {
                    Section {
                        Text(accountCreationError)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(accountCreationTarget == .source ? "新增账户" : "新增转入账户")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isAccountCreatorPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加", action: createAccount)
                }
            }
        }
    }

    private func presentAccountCreator(for target: AccountCreationTarget) {
        accountCreationTarget = target
        newAccountName = ""
        newAccountType = .asset
        newAccountCurrency = "CNY"
        accountCreationError = nil
        isAccountCreatorPresented = true
    }

    private func createAccount() {
        do {
            let draft = try AccountEntryCoordinator.makeDraft(
                name: newAccountName,
                type: newAccountType,
                currencyCode: newAccountCurrency,
                existingAccountNames: accounts.map(\.name)
            )
            let newAccount = Account(
                name: draft.name,
                type: draft.type,
                currencyCode: draft.currencyCode
            )
            modelContext.insert(newAccount)
            do {
                try modelContext.save()
            } catch {
                modelContext.delete(newAccount)
                throw error
            }
            let selection = AccountEntryCoordinator.selecting(
                accountNamed: newAccount.name,
                for: accountCreationTarget,
                from: AccountSelectionState(
                    sourceAccountName: account,
                    destinationAccountName: destination
                )
            )
            account = selection.sourceAccountName
            destination = selection.destinationAccountName
            isAccountCreatorPresented = false
        } catch {
            accountCreationError = error.localizedDescription
        }
    }

    private func save() {
        guard let value else { errorMessage = "请输入有效金额。"; return }
        let title = payee.isEmpty ? category : payee
        let postings: [Posting]
        switch type { case .expense: postings = [Posting(accountName: "Expenses:\(category)", amount: value, memo: title), Posting(accountName: account, amount: -value)]; case .income: postings = [Posting(accountName: account, amount: value), Posting(accountName: "Income:\(category)", amount: -value, memo: title)]; case .transfer: postings = [Posting(accountName: destination, amount: value), Posting(accountName: account, amount: -value)] }
        do { try TransactionService.create(date: date, payee: title, note: note, postings: postings, in: modelContext); dismiss() } catch { errorMessage = error.localizedDescription }
    }
}
