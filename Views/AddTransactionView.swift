import Foundation
import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Category.name) private var storedCategories: [Category]

    @State private var type: TransactionEntryKind = .expense
    @State private var amount = ""
    @State private var sourceAccountID: UUID?
    @State private var destinationAccountID: UUID?
    @State private var selectedCategoryID = ""
    @State private var payee = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var errorMessage: String?
    @FocusState private var isAmountFocused: Bool

    @State private var isAccountCreatorPresented = false
    @State private var accountCreationTarget: AccountSelectionTarget = .source
    @State private var newAccountName = ""
    @State private var newAccountType: AccountType = .asset
    @State private var newAccountCurrency = "CNY"
    @State private var accountCreationError: String?
    @State private var categoryCreationKind: CategoryCreationKind?

    private var categoryOptions: [LedgerCategoryOption] {
        LedgerCategoryCatalog.options(for: type, storedCategories: storedCategories)
    }

    private var selectedCategory: LedgerCategoryOption? {
        categoryOptions.first { $0.id == selectedCategoryID }
    }

    private var sourceAccount: Account? {
        accounts.first { $0.id == sourceAccountID }
    }

    private var destinationAccount: Account? {
        accounts.first { $0.id == destinationAccountID }
    }

    private var parsedAmount: Decimal? {
        try? MoneyInput.validatedDecimal(from: amount)
    }

    private var canSave: Bool {
        guard parsedAmount != nil, sourceAccount != nil else { return false }
        switch type {
        case .expense, .income:
            return selectedCategory != nil
        case .transfer:
            return destinationAccount != nil && sourceAccountID != destinationAccountID
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                transactionTypeSection
                amountSection
                accountSection
                detailSection

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
        .sheet(item: $categoryCreationKind) { kind in
            CategoryCreationSheet(kind: kind) { category in
                selectedCategoryID = LedgerCategoryOption(
                    name: category.name,
                    isIncome: category.isIncome
                ).id
            }
        }
        .onAppear(perform: synchronizeCategorySelection)
        .onChange(of: type) { _, _ in
            synchronizeCategorySelection()
            errorMessage = nil
        }
        .onChange(of: storedCategories.count) { _, _ in
            synchronizeCategorySelection()
        }
        .onChange(of: isAmountFocused) { _, isFocused in
            guard !isFocused, let parsedAmount else { return }
            amount = MoneyInput.display(parsedAmount)
        }
    }

    private var transactionTypeSection: some View {
        Section {
            Picker("类型", selection: $type) {
                ForEach(TransactionEntryKind.allCases) { entryType in
                    Text(entryType.rawValue).tag(entryType)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var amountSection: some View {
        Section("金额") {
            HStack {
                Text("¥")
                TextField("0.00", text: $amount)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .monospacedDigit()
            }

            if let parsedAmount {
                LabeledContent("记账金额") {
                    Text("¥ \(MoneyInput.display(parsedAmount))")
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
            } else {
                Text("金额最多保留两位小数，精确到分。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var accountSection: some View {
        Section("账户") {
            Picker(type == .transfer ? "转出账户" : "账户", selection: $sourceAccountID) {
                Text("请选择账户").tag(UUID?.none)
                ForEach(accounts) { account in
                    Text(account.selectionLabel).tag(Optional(account.id))
                }
            }

            Button {
                presentAccountCreator(for: .source)
            } label: {
                Label(type == .transfer ? "新增转出账户" : "新增账户", systemImage: "plus.circle")
            }

            if type == .transfer {
                Picker("转入账户", selection: $destinationAccountID) {
                    Text("请选择账户").tag(UUID?.none)
                    ForEach(accounts.filter { $0.id != sourceAccountID }) { account in
                        Text(account.selectionLabel).tag(Optional(account.id))
                    }
                }

                Button {
                    presentAccountCreator(for: .destination)
                } label: {
                    Label("新增转入账户", systemImage: "plus.circle")
                }

                Text("转账使用转出账户和转入账户的标准账本路径，且两者不得相同。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let sourceAccount {
                LabeledContent("记账账户") {
                    Text(sourceAccount.ledgerName)
                        .font(.footnote.monospaced())
                }
                .foregroundStyle(.secondary)
            }

            if accounts.isEmpty {
                Text("还没有账户。请先新增一个账户再保存交易。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var detailSection: some View {
        Section("详情") {
            TextField(type == .income ? "收入来源" : "商户", text: $payee)

            if type != .transfer {
                Picker("分类", selection: $selectedCategoryID) {
                    Text("请选择分类").tag("")
                    ForEach(categoryOptions) { category in
                        Text(category.name).tag(category.id)
                    }
                }

                Button {
                    categoryCreationKind = type == .income ? .income : .expense
                } label: {
                    Label(type == .income ? "新增收入分类" : "新增支出分类", systemImage: "plus.circle")
                }

                if let selectedCategory {
                    LabeledContent("账本分类") {
                        Text(selectedCategory.ledgerName)
                            .font(.footnote.monospaced())
                    }
                    .foregroundStyle(.secondary)
                }
            }

            TextField("备注（可选）", text: $note)
            DatePicker("日期", selection: $date, displayedComponents: [.date, .hourAndMinute])
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

    private func synchronizeCategorySelection() {
        guard type != .transfer else {
            selectedCategoryID = ""
            return
        }
        if !categoryOptions.contains(where: { $0.id == selectedCategoryID }) {
            selectedCategoryID = categoryOptions.first?.id ?? ""
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
                accountID: newAccount.id,
                for: accountCreationTarget,
                from: AccountSelectionState(
                    sourceAccountID: sourceAccountID,
                    destinationAccountID: destinationAccountID
                )
            )
            sourceAccountID = selection.sourceAccountID
            destinationAccountID = selection.destinationAccountID
            isAccountCreatorPresented = false
        } catch {
            accountCreationError = error.localizedDescription
        }
    }

    private func save() {
        do {
            let amount = try MoneyInput.validatedDecimal(from: amount)
            let resolvedPayee = payee.trimmingCharacters(in: .whitespacesAndNewlines)
            let defaultPayee = type == .transfer ? "账户转账" : (selectedCategory?.name ?? "")
            let postings = try TransactionEntryDraft(
                kind: type,
                amount: amount,
                sourceAccount: sourceAccount,
                destinationAccount: destinationAccount,
                category: selectedCategory,
                payee: resolvedPayee.isEmpty ? defaultPayee : resolvedPayee
            ).makePostings()

            try TransactionService.create(
                date: date,
                payee: resolvedPayee.isEmpty ? defaultPayee : resolvedPayee,
                note: note,
                currencyCode: sourceAccount?.currencyCode ?? "CNY",
                source: "手动录入",
                postings: postings,
                in: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
