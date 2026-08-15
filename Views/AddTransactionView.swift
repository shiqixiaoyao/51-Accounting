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
    @State private var icon = "fork.knife"
    @State private var date = Date()

    private let defaults = ["CCB 1843", "ABC 0278", "BGY 5980", "Huabei", "现金"]
    private let categories = [("餐饮", "fork.knife"), ("交通", "car.fill"), ("购物", "bag.fill"), ("居住", "house.fill"), ("娱乐", "gamecontroller.fill"), ("其他", "ellipsis.circle.fill")]
    private var accountOptions: [String] { Array(Set(accounts.map(\.name) + defaults)).sorted() }
    private var value: Decimal? { Decimal(string: amount.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX")) }
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
                    HStack { Image(systemName: icon).foregroundStyle(.cyan); Picker("分类", selection: $category) { ForEach(categories, id: \.0) { Text($0.0).tag($0.0) } } }
                    TextField("备注（可选）", text: $note)
                    DatePicker("日期", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                Section { Button("保存交易") { save() }.frame(maxWidth: .infinity).disabled(!canSave) } footer: { Text("金额精确到小数点后两位") }
            }
            .navigationTitle("新增记账").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
        .onAppear { if account.isEmpty { account = accountOptions.first ?? "" } }
    }

    private func save() {
        guard let value else { return }
        let amount = value.rounded(scale: 2)
        let title = payee.isEmpty ? category : payee
        var postings: [Posting]
        switch type {
        case .expense: postings = [Posting(accountName: "Expenses:\(category)", amount: amount, memo: title), Posting(accountName: account, amount: -amount)]
        case .income: postings = [Posting(accountName: account, amount: amount), Posting(accountName: "Income:\(category)", amount: -amount, memo: title)]
        case .transfer: postings = [Posting(accountName: destination, amount: amount), Posting(accountName: account, amount: -amount)]
        }
        modelContext.insert(BookkeepingTransaction(date: date, payee: title, note: note, postings: postings))
        try? modelContext.save()
        dismiss()
    }
}

private extension Decimal {
    func rounded(scale: Int) -> Decimal { var value = self; var result = Decimal(); NSDecimalRound(&result, &value, scale, .bankers); return result }
}
