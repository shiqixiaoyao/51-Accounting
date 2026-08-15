import SwiftUI
import SwiftData

enum TransactionEntryType: String, CaseIterable, Identifiable {
    case expense = "支出"
    case income = "收入"
    case transfer = "转账"
    var id: String { rawValue }
}

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

    private let defaults = ["CCB 1843", "ABC 0278", "BGY 5980", "Huabei", "现金"]
    private let categories = [("餐饮", "fork.knife"), ("交通", "car.fill"), ("购物", "bag.fill"), ("居住", "house.fill"), ("娱乐", "gamecontroller.fill"), ("其他", "ellipsis.circle.fill")]
    private var accountOptions: [String] { Array(Set(accounts.map { $0.name } + defaults)).sorted() }
    private var value: Decimal? { Decimal(string: amount.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX"))?.roundedToCents }
    private var canSave: Bool { guard let value else { return false }; return value > 0 && !account.isEmpty && (type != .transfer || !destination.isEmpty) }

    var body: some View {
        NavigationStack {
            Form {
                Section { Picker("类型", selection: $type) { ForEach(TransactionEntryType.allCases) { Text($0.rawValue).tag($0) }.pickerStyle(.segmented) } }
                Section("金额") { HStack { Text("¥").font(.title2.weight(.bold)); TextField("0.00", text: $amount).keyboardType(.decimalPad).font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit()) } }
                Section("账户") {
                    Picker(type == .transfer ? "转出账户" : "账户", selection: $account) { Text("选择账户").tag(""); ForEach(accountOptions, id: \.self) { Text($0).tag($0) } }
                    if type == .transfer { Picker("转入账户", selection: $destination) { Text("选择账户").tag(""); ForEach(accountOptions.filter { $0 != account }, id: \.self) { Text($0).tag($0) } } }
                }
                Section("详情") {
                    TextField("商户 / 收入来源", text: $payee)
                    Picker("分类", selection: $category) { ForEach(categories, id: \.0) { Text($0.0).tag($0.0) } }
                    TextField("备注（可选）", text: $note)
                    DatePicker("日期", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                if let errorMessage { Section { Label(errorMessage, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) } }
                Section { Button("保存交易") { save() }.frame(maxWidth: .infinity).disabled(!canSave) } footer: { Text("金额最多保留两位小数；保存前会校验借贷平衡") }
            }
            .navigationTitle("新增记账").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
        .onAppear { if account.isEmpty { account = accountOptions.first ?? "" } }
    }

    private func save() {
        guard let value else { errorMessage = "请输入有效金额，最多保留两位小数。"; return }
        let title = payee.isEmpty ? category : payee
        let postings: [Posting]
        switch type {
        case .expense: postings = [Posting(accountName: "Expenses:\(category)", amount: value, memo: title), Posting(accountName: account, amount: -value)]
        case .income: postings = [Posting(accountName: account, amount: value), Posting(accountName: "Income:\(category)", amount: -value, memo: title)]
        case .transfer: postings = [Posting(accountName: destination, amount: value), Posting(accountName: account, amount: -value)]
        }
        let transaction = BookkeepingTransaction(date: date, payee: title, note: note, postings: postings)
        switch TransactionValidator.validate(transaction) {
        case .success:
            modelContext.insert(transaction)
            do { try modelContext.save(); dismiss() } catch { errorMessage = "保存失败，请稍后重试：\(error.localizedDescription)" }
        case .failure(let error): errorMessage = error.localizedDescription
        }
    }
}
