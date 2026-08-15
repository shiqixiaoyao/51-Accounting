import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \.createdAt) private var accounts: [Account]
    @Query(sort: \.name) private var categories: [Category]
    @Query(sort: \.date) private var transactions: [BookkeepingTransaction]
    @State private var exportDocument: AccountingFileDocument?
    @State private var exportName = ""
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var conflict: ImportConflict = .merge
    @State private var message = ""
    @State private var error = ""
    @State private var shareItems: [Any] = []

    var body: some View {
        Form {
            Section("导出") {
                Button("导出 Beancount (.bean)") { prepare(DataTransferService.beancount(transactions), name: "51-accounting.bean", share: true) }
                Button("导出交易 CSV") { prepare(DataTransferService.csv(transactions), name: "51-transactions.csv", share: false) }
                Button("导出 JSON 完整备份") { do { prepare(try DataTransferService.backup(accounts: accounts, categories: categories, transactions: transactions), name: "51-backup.json", share: false) } catch { error = error.localizedDescription } }
                Button("复制 Beancount 到剪贴板") { UIPasteboard.general.string = String(data: DataTransferService.beancount(transactions), encoding: .utf8); message = "已复制到剪贴板" }
            }
            Section("导入与恢复") {
                Picker("冲突处理", selection: $conflict) { ForEach(ImportConflict.allCases) { Text($0.rawValue).tag($0) } }
                Button("从文件导入 JSON / Beancount") { showingImporter = true }
                Text("JSON 可恢复账户、分类、交易和分录；Beancount 文件将按交易段落导入。导入前会校验借贷平衡。").font(.caption).foregroundStyle(.secondary)
            }
            if !message.isEmpty { Text(message).foregroundStyle(.green) }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("数据管理")
        .fileExporter(isPresented: $showingExporter, document: exportDocument, contentType: .data, defaultFilename: exportName) { result in if case .failure(let failure) = result { error = failure.localizedDescription } }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json, .plainText, .commaSeparatedText], allowsMultipleSelection: false) { result in importFile(result) }
        .sheet(isPresented: Binding(get: { !shareItems.isEmpty }, set: { if !$0 { shareItems = [] } })) { ActivityView(activityItems: shareItems) }
    }

    private func prepare(_ data: Data, name: String, share: Bool) { exportDocument = AccountingFileDocument(data: data); exportName = name; showingExporter = true; if share { shareItems = [data] } }
    private func importFile(_ result: Result<[URL], Error>) { do { guard let url = try result.get().first else { return }; guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }; defer { url.stopAccessingSecurityScopedResource() }; let data = try Data(contentsOf: url); if url.pathExtension.lowercased() == "json" { try DataTransferService.restore(DataTransferService.readBackup(data), in: modelContext, conflict: conflict); message = "JSON 备份已恢复" } else { let count = try importBean(data); message = "已导入 \(count) 笔 Beancount 交易" } } catch { error = error.localizedDescription } }
    private func importBean(_ data: Data) throws -> Int { guard let text = String(data: data, encoding: .utf8) else { throw DataTransferError.invalidBackup }; var count = 0; for block in text.components(separatedBy: "\n\n") { let lines = block.split(separator: "\n").map(String.init); guard let header = lines.first, header.count >= 10, let date = ISO8601DateFormatter().date(from: String(header.prefix(10)) + "T00:00:00Z") else { continue }; let payee = header.components(separatedBy: "\"").dropFirst().first ?? header; var postings: [Posting] = []; for line in lines.dropFirst() { let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" }); if parts.count >= 3, let amount = Decimal(string: String(parts[1])) { postings.append(Posting(accountName: String(parts[0]), amount: amount, memo: "")) } }; if !postings.isEmpty && postings.reduce(Decimal.zero, { $0 + $1.amount }) == 0 { modelContext.insert(BookkeepingTransaction(date: date, payee: payee, postings: postings)); count += 1 } }; try modelContext.save(); return count }
}

struct ActivityView: UIViewControllerRepresentable { let activityItems: [Any]; func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: activityItems, applicationActivities: nil) }; func updateUIViewController(_ controller: UIActivityViewController, context: Context) {} }
