import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

@MainActor
struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor<Account>(\.createdAt)]) private var accounts: [Account]
    @Query(sort: [SortDescriptor<Category>(\.name)]) private var categories: [Category]
    @Query(sort: [SortDescriptor<BookkeepingTransaction>(\.date)]) private var transactions: [BookkeepingTransaction]
    @State private var exportDocument: AccountingFileDocument?
    @State private var exportName = ""
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showingRestorePreview = false
    @State private var pendingBackup: AccountingBackup?
    @State private var pendingSummary: BackupSummary?
    @State private var scope: BackupScope = .complete
    @State private var conflict: ImportConflict = .merge
    @State private var message = ""
    @State private var errorMessage = ""

    var body: some View {
        Form {
            Section("本地导出") {
                Picker("JSON 备份范围", selection: $scope) {
                    ForEach(BackupScope.allCases) { Text($0.rawValue).tag($0) }
                }
                Text(scope.description).font(.footnote).foregroundStyle(.secondary)
                Button("导出 JSON 备份") { exportJSONBackup() }
                Button("导出 Beancount (.bean)") {
                    prepare(DataTransferService.beancount(transactions), "51-accounting-\(Date().timeIntervalSince1970.formatted(.number.precision(.fractionLength(0)))).bean")
                }
            }

            Section("导入与恢复") {
                Picker("冲突处理", selection: $conflict) {
                    ForEach(ImportConflict.allCases) { Text($0.rawValue).tag($0) }
                }
                Text("选择 JSON 文件后会先校验格式和借贷平衡，并显示账户、分类、交易和分录数量，再执行恢复。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("选择 JSON / Beancount 文件") { showingImporter = true }
            }

            if !message.isEmpty { Section { Text(message).foregroundStyle(.green) } }
            if !errorMessage.isEmpty { Section { Text(errorMessage).foregroundStyle(.red) } }
        }
        .navigationTitle("数据管理")
        .fileExporter(isPresented: $showingExporter, document: exportDocument, contentType: .data, defaultFilename: exportName) {
            if case .failure(let error) = $0 { errorMessage = error.localizedDescription }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json, .plainText], allowsMultipleSelection: false) {
            prepareImport($0)
        }
        .alert("恢复前预览", isPresented: $showingRestorePreview, presenting: pendingSummary) { summary in
            Button("取消", role: .cancel) { clearPendingRestore() }
            Button(conflict == .replaceAll ? "确认清空并恢复" : "确认恢复", role: conflict == .replaceAll ? .destructive : nil) {
                restorePendingBackup()
            }
        } message: { summary in
            Text("备份时间：\(summary.exportedAt.formatted(date: .abbreviated, time: .shortened))\n账户：\(summary.accountCount) 个\n分类：\(summary.categoryCount) 个\n交易：\(summary.transactionCount) 笔\n分录：\(summary.postingCount) 条")
        }
    }

    private func prepare(_ data: Data, _ name: String) {
        exportDocument = AccountingFileDocument(data: data)
        exportName = name
        showingExporter = true
    }

    private func exportJSONBackup() {
        do {
            let data = try DataTransferService.backup(accounts: accounts, categories: categories, transactions: transactions, scope: scope)
            prepare(data, BackupFilename.localFilename(scope: scope))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func prepareImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            if url.pathExtension.lowercased() == "json" {
                let backup = try DataTransferService.readBackup(data)
                pendingBackup = backup
                pendingSummary = DataTransferService.summary(for: backup)
                showingRestorePreview = true
            } else {
                let count = try importBean(data)
                message = "已导入 \(count) 笔 Beancount 交易"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restorePendingBackup() {
        do {
            guard let pendingBackup else { return }
            try DataTransferService.restore(pendingBackup, in: modelContext, conflict: conflict)
            message = "JSON 备份已恢复"
            clearPendingRestore()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearPendingRestore() {
        pendingBackup = nil
        pendingSummary = nil
    }

    private func importBean(_ data: Data) throws -> Int {
        guard let text = String(data: data, encoding: .utf8) else { throw DataTransferError.invalidBackup }
        var count = 0
        for block in text.components(separatedBy: "\n\n") {
            let lines = block.split(separator: "\n").map(String.init)
            guard let header = lines.first, let date = ISO8601DateFormatter().date(from: String(header.prefix(10)) + "T00:00:00Z") else { continue }
            let payee = header.components(separatedBy: "\"").dropFirst().first ?? header
            var postings: [Posting] = []
            for line in lines.dropFirst() {
                let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
                if parts.count >= 3, let amount = Decimal(string: String(parts[1])) {
                    postings.append(Posting(accountName: String(parts[0]), amount: amount, memo: ""))
                }
            }
            guard !postings.isEmpty else { continue }
            try TransactionService.create(date: date, payee: payee, postings: postings, in: modelContext)
            count += 1
        }
        return count
    }
}
