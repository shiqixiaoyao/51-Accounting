import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

@MainActor struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor<Account>(\.createdAt)]) private var accounts: [Account]
    @Query(sort: [SortDescriptor<Category>(\.name)]) private var categories: [Category]
    @Query(sort: [SortDescriptor<BookkeepingTransaction>(\.date)]) private var transactions: [BookkeepingTransaction]
    @State private var exportDocument: AccountingFileDocument?
    @State private var exportName = ""
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var conflict: ImportConflict = .merge
    @State private var message = ""
    @State private var errorMessage = ""
    var body: some View { Form { Section("导出") { Button("导出 Beancount (.bean)") { prepare(DataTransferService.beancount(transactions), "51-accounting.bean") }; Button("导出 JSON 完整备份") { do { prepare(try DataTransferService.backup(accounts: accounts, categories: categories, transactions: transactions), "51-backup.json") } catch { errorMessage = error.localizedDescription } } }; Section("导入与恢复") { Picker("冲突处理", selection: $conflict) { ForEach(ImportConflict.allCases) { Text($0.rawValue).tag($0) } }; Button("从文件导入 JSON / Beancount") { showingImporter = true } }; if !message.isEmpty { Text(message).foregroundStyle(.green) }; if !errorMessage.isEmpty { Text(errorMessage).foregroundStyle(.red) } }.navigationTitle("数据管理").fileExporter(isPresented: $showingExporter, document: exportDocument, contentType: .data, defaultFilename: exportName) { if case .failure(let error) = $0 { errorMessage = error.localizedDescription } }.fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json, .plainText], allowsMultipleSelection: false) { importFile($0) } }
    private func prepare(_ data: Data, _ name: String) { exportDocument = AccountingFileDocument(data: data); exportName = name; showingExporter = true }
    private func importFile(_ result: Result<[URL], Error>) { do { guard let url = try result.get().first else { return }; guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }; defer { url.stopAccessingSecurityScopedResource() }; let data = try Data(contentsOf: url); if url.pathExtension.lowercased() == "json" { try DataTransferService.restore(DataTransferService.readBackup(data), in: modelContext, conflict: conflict); message = "JSON 备份已恢复" } else { let count = try importBean(data); message = "已导入 \(count) 笔 Beancount 交易" } } catch { errorMessage = error.localizedDescription } }
    private func importBean(_ data: Data) throws -> Int { guard let text = String(data: data, encoding: .utf8) else { throw DataTransferError.invalidBackup }; var count = 0; for block in text.components(separatedBy: "\n\n") { let lines = block.split(separator: "\n").map(String.init); guard let header = lines.first, let date = ISO8601DateFormatter().date(from: String(header.prefix(10)) + "T00:00:00Z") else { continue }; let payee = header.components(separatedBy: "\"").dropFirst().first ?? header; var postings: [Posting] = []; for line in lines.dropFirst() { let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" }); if parts.count >= 3, let amount = Decimal(string: String(parts[1])) { postings.append(Posting(accountName: String(parts[0]), amount: amount, memo: "")) } }; guard !postings.isEmpty else { continue }; try TransactionService.create(date: date, payee: payee, postings: postings, in: modelContext); count += 1 }; return count }
}
