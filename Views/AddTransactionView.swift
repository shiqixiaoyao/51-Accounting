import Foundation
import SwiftUI
import SwiftData

enum TransactionEntryType: String, CaseIterable, Identifiable {
    case expense = "支出"
    case income = "收入"
    case transfer = "转账"

    var id: String { rawValue }
}

struct AddTransactionView: View {
    private static let noAccount = UUID()

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \.Account.createdAt) private var accounts: [Account]
    @Query(sort: \.Category.name) private var storedCategories: [Category]

    @State private var type: TransactionEntryType = .expense
    @State private var amount = ""
    @State private var sourceAccountID = AddTransactionView.noAccount
    @State private var destinationAccountID = AddTransactionView.noAccount
    @State private var payee = ""
    @State private var category = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var errorMessage: String?
    @State private var isAccountCreatorPresented = false
    @State private var accountCreationTarget: AccountSelectionTarget = .source
    @State private var newAccountName = ""
    @State private var newAccountType: AccountType = .asset
    @State private var newAccountCurrency = "CNY"
    @State private var accountCreationError: String?

    private let fallbackExpenseCategories = ["餐饮", "交通", "购物", "居住", "娱乐", "其他"]
    private let fallbackIncomeCategories = ["工资", "奖金", "利息", "投资收益", "其他"]

    private var selectedSource: Account? { accounts.first { $0.id == sourceAccountID } }
    private var selectedDestination: Account? { accounts.first { $0.id == destinationAccountID } }

    private var availableCategories: [String] {
        guard type != .transfer else { return [] }
        let matching = storedCategories.filter { $0.isIncome == (type == .income) }.map(\.name)
        let fallback = type == .income ? fallbackIncomeCategories : fallbackExpenseCategories
        return Array(Set(matching + fallback)).sorted()
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amount.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX"))?.roundedToCents
    }

    private var formattedAmount: String {
        guard let parsedAmount else { return amount }
        return NSDecimalNumber(decimal: parsedAmount).stringValue
    }

    private var canSave: Bool {
        guard let value = parsedAmount, value > 0, selectedSource != nil else { return false }
        return type != .transfer || selectedDestination != nil && selectedDestination?.id != selectedSource?.id
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
                            .monospacedDigit()
                        if parsedAmount != nil {
                            Text(formattedAmount)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                Section("账户") {
                    accountPicker(title: type == .transfer ? "转出账户" : "账户", selection: $sourceAccountID, excluding: nil)
                    Button { presentAccountCreator(for: .source) } label: {
                        Label(type == .transfer ? "新增转出账户" : "新增账户", systemImage: "plus.circle")
                    }

                    if type == .transfer {
                        accountPicker(title: "转入账户", selection: $destinationAccountID, excluding: sourceAccountID)
                        Button { presentAccountCreator(for: .destination) } label: {
                            Label("新增转入账户", systemImage: "plus.circle")
                        }
                    }

                    if accounts.isEmpty {
                        Text("还没有账户。请先新增一个账户再保存交易。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if type != .transfer {
                    Section("分类") {
                        Picker("分类", selection: $category) {
                            Text("请选择分类").tag("")
                            ForEach(availableCategories, id: \.self) { item in
                                Text(item).tag(item)
                            }
                        }
                    }
                }

                Section("详情") {
                    TextField("商户 / 收入来源", text: $payee)
                    TextField("备注（可选）", text: $note)
                    DatePicker("日期", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }

                Section {
                    Button("保存交易", action: save)
                        .disabled(!canSave)
                }
            }
            .navigationTitle("新增记账")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .onChange(of: type) { _, newType in
                if newType == .transfer { category = "" }
                else if !availableCategories.contains(category) { category = availableCategories.first ?? "" }
            }
            .onChange(of: storedCategories.count) { _, _ in
                if type != .transfer && !availableCategories.contains(category) { category = availableCategories.first ?? "" }
            }
        }
        .sheet(isPresented: $isAccountCreatorPresented) { accountCreator }
    }

    private func accountPicker(title: String, selection: Binding<UUID>, excluding: UUID?) -> some View {
        Picker(title, selection: selection) {
            Text("请选择账户").tag(Self.noAccount)
            ForEach(accounts.filter { $0.id != excluding }, id: \.id) { account in
                Text("\(account.name) · \(account.type.chineseName)").tag(account.id)
            }
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
                if let accountCreationError { Section { Text(accountCreationError).foregroundStyle(.red) } }
            }
            .navigationTitle(accountCreationTarget == .source ? "新增账户" : "新增转入账户")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { isAccountCreatorPresented = false } }
                ToolbarItem(placement: .confirmationAction) { Button("添加", action: createAccount) }
            }
        }
    }

    private func presentAccountCreator(for target: AccountSelectionTarget) {
        accountCreationTarget = target
        newAccountName = ""
        newAccountType = .asset
        newAccountCurrency = "CNY"
        accountCreationError = nil
        isAccountCreatorPresented = true
    }

    private func createAccount() {
        do {
            let draft = try AccountEntryCoordinator.makeDraft(name: newAccountName, type: newAccountType, currencyCode: newAccountCurrency, existingAccountNames: accounts.map(\.name))
            let newAccount = Account(name: draft.name, type: draft.type, currencyCode: draft.currencyCode)
            modelContext.insert(newAccount)
            try modelContext.save()
            if accountCreationTarget == .source { sourceAccountID = newAccount.id }
            else { destinationAccountID = newAccount.id }
            isAccountCreatorPresented = false
        } catch {
            accountCreationError = error.localizedDescription
        }
    }

    private func save() {
        guard let value = parsedAmount else { errorMessage = "请输入有效金额。"; return }
        guard let source = selectedSource else { errorMessage = "请选择账户。"; return }
        let title = payee.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (category.isEmpty ? type.rawValue : category) : payee.trimmingCharacters(in: .whitespacesAndNewlines)
        let postings: [Posting]
        switch type {
        case .expense:
            guard !category.isEmpty else { errorMessage = "请选择支出分类。"; return }
            postings = [Posting(accountName: "Expenses:\(category)", amount: value, memo: title), Posting(accountName: source.ledgerName, amount: -value)]
        case .income:
            guard !category.isEmpty else { errorMessage = "请选择收入分类。"; return }
            postings = [Posting(accountName: source.ledgerName, amount: value), Posting(accountName: "Income:\(category)", amount: -value, memo: title)]
        case .transfer:
            guard let destination = selectedDestination, destination.id != source.id else { errorMessage = "请选择两个不同的账户。"; return }
            postings = [Posting(accountName: destination.ledgerName, amount: value), Posting(accountName: source.ledgerName, amount: -value)]
        }
        do {
            try TransactionService.create(date: date, payee: title, note: note, currencyCode: source.currencyCode, postings: postings, in: modelContext)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
