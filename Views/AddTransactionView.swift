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
    private let defaults = ["CCB 1843", "ABC 0278", "BGY 5980", "Huabei", "现金"]
    private let categories = ["餐饮", "交通", "购物", "居住", "娱乐", "其他"]
    private var accountOptions: [String] { Array(Set(accounts.map(\.name) + defaults)).sorted() }
    private var value: Decimal? { Decimal(string: amount.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX")) }
    private var canSave: Bool { guard let value else { return false }; return value > 0 && !account.isEmpty && (type != .transfer || !destination.isEmpty) }
    var body: some View {
        NavigationStack { Form {
            Section { Picker("类型", selection: $type) { ForEach(TransactionEntryType.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented) }
            Section("金额") { HStack { Text("¥"); TextField("0.00", text: $amount).keyboardType(.decimalPad) } }
            Section("账户") { Picker(type == .transfer ? "转出账户" : "账户", selection: $account) { Text("选择账户").tag(""); ForEach(accountOptions, id: \.self) { Text($0).tag($0) } }; if type == .transfer { Picker("转入账户", selection: $destination) { Text("选择账户").tag(""); ForEach(accountOptions.filter { $0 != account }, id: \.self) { Text($0).tag($0) } } } }
            Section("详情") { TextField("商户 / 收入来源", text: $payee); Picker("分类", selection: $category) { ForEach(categories, id: \.self) { Text($0).tag($0) } }; TextField("备注（可选）", text: $note); DatePicker("日期", selection: $date, displayedComponents: [.date, .hourAndMinute]) }
            if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
            Section { Button("保存交易", action: save).disabled(!canSave) }
        }.navigationTitle("新增记账").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } } }.onAppear { if account.isEmpty { account = accountOptions.first ?? "" } }
    }
    private func save() {
        guard let value else { errorMessage = "请输入有效金额。"; return }
        let title = payee.isEmpty ? category : payee
        let postings: [Posting]
        switch type { case .expense: postings = [Posting(accountName: "Expenses:\(category)", amount: value, memo: title), Posting(accountName: account, amount: -value)]; case .income: postings = [Posting(accountName: account, amount: value), Posting(accountName: "Income:\(category)", amount: -value, memo: title)]; case .transfer: postings = [Posting(accountName: destination, amount: value), Posting(accountName: account, amount: -value)] }
        do { try TransactionService.create(date: date, payee: title, note: note, postings: postings, in: modelContext); dismiss() } catch { errorMessage = error.localizedDescription }
    }
}
