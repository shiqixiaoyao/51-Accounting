import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@MainActor
struct CloudBackupView: View {
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \BookkeepingTransaction.date) private var transactions: [BookkeepingTransaction]

    @AppStorage("webDAVLastBackupTime") private var lastBackupTime = 0.0
    @AppStorage("webDAVLastBackupFilename") private var lastBackupFilename = ""
    @State private var isEnabled = false
    @State private var endpoint = ""
    @State private var username = ""
    @State private var password = ""
    @State private var scope: BackupScope = .complete
    @State private var target: WebDAVBackupTarget = .latest
    @State private var snapshotName = ""
    @State private var exportDocument: AccountingFileDocument?
    @State private var exportName = ""
    @State private var showingExporter = false
    @State private var message: String?
    @State private var errorMessage: String?
    @State private var isWorking = false

    private var lastBackupDate: Date? {
        lastBackupTime > 0 ? Date(timeIntervalSince1970: lastBackupTime) : nil
    }

    var body: some View {
        Form {
            Section("WebDAV 云备份") {
                Toggle("启用 WebDAV 云备份", isOn: $isEnabled)
                TextField("HTTPS WebDAV 目录地址", text: $endpoint)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                TextField("用户名", text: $username)
                    .textInputAutocapitalization(.never)
                SecureField("密码或应用专用密码", text: $password)
            }

            Section("备份内容") {
                Picker("备份范围", selection: $scope) {
                    ForEach(BackupScope.allCases) { Text($0.rawValue).tag($0) }
                }
                Text(scope.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                LabeledContent("当前可导出") {
                    Text("\(accounts.count) 账户 · \(categories.count) 分类 · \(transactions.count) 交易")
                        .monospacedDigit()
                }
            }

            Section("云端文件") {
                Picker("保存方式", selection: $target) {
                    ForEach(WebDAVBackupTarget.allCases) { Text($0.rawValue).tag($0) }
                }
                if target == .snapshot {
                    TextField("快照名称，例如月末结账", text: $snapshotName)
                }
                Text(target == .latest ? "将覆盖云端的 latest 文件，适合日常同步。" : "将创建带时间戳的独立快照，适合月末或重要操作前留档。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("备份操作") {
                if let lastBackupDate {
                    LabeledContent("最近成功备份") {
                        Text(lastBackupDate.formatted(date: .abbreviated, time: .shortened))
                            .monospacedDigit()
                    }
                    if !lastBackupFilename.isEmpty {
                        Text(lastBackupFilename)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Button { Task { await testConnection() } } label: {
                    actionLabel("测试连接", systemImage: "checkmark.icloud")
                }
                .disabled(isWorking || !isEnabled)

                Button { Task { await uploadBackup() } } label: {
                    actionLabel(target == .latest ? "更新云端最新备份" : "创建云端快照", systemImage: "arrow.up.doc")
                }
                .disabled(isWorking || !isEnabled)

                Button { exportLocalBackup() } label: {
                    Label("导出本地 JSON 备份", systemImage: "square.and.arrow.down")
                }
                .disabled(isWorking)
            }

            if let message { Section { Text(message).foregroundStyle(.green) } }
            if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
        }
        .navigationTitle("云端备份")
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportName
        ) { result in
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
        }
        .onAppear(perform: load)
    }

    @ViewBuilder
    private func actionLabel(_ title: String, systemImage: String) -> some View {
        if isWorking { HStack { ProgressView(); Text("正在处理") } }
        else { Label(title, systemImage: systemImage) }
    }

    private func load() {
        WebDAVSettingsStore.migrateLegacyCredential()
        isEnabled = WebDAVSettingsStore.isEnabled()
        endpoint = UserDefaults.standard.string(forKey: "webDAVEndpoint") ?? ""
        username = UserDefaults.standard.string(forKey: "webDAVUsername") ?? ""
        password = KeychainStore.read("webDAVPassword") ?? ""
    }

    private func configuration() throws -> WebDAVConfiguration {
        try WebDAVSettingsStore.makeConfiguration(endpointText: endpoint, username: username, password: password)
    }

    private func persistConfiguration() throws -> WebDAVConfiguration {
        let value = try configuration()
        try WebDAVSettingsStore.save(endpointText: endpoint, username: username, password: password, enabled: isEnabled)
        return value
    }

    private func backupData() throws -> Data {
        try DataTransferService.backup(accounts: accounts, categories: categories, transactions: transactions, scope: scope)
    }

    private func testConnection() async {
        do {
            let value = try persistConfiguration()
            isWorking = true
            defer { isWorking = false }
            try await BackupManager().testWebDAVConnection(configuration: value)
            errorMessage = nil
            message = "WebDAV 连接成功，目录可访问。"
        } catch {
            message = nil
            errorMessage = error.localizedDescription
        }
    }

    private func uploadBackup() async {
        do {
            let value = try persistConfiguration()
            let filename = BackupFilename.webDAVFilename(scope: scope, target: target, snapshotName: snapshotName)
            let data = try backupData()
            isWorking = true
            defer { isWorking = false }
            let receipt = try await BackupManager().uploadWebDAV(data: data, filename: filename, configuration: value)
            lastBackupTime = receipt.uploadedAt.timeIntervalSince1970
            lastBackupFilename = receipt.filename
            errorMessage = nil
            message = "云端备份成功：\(receipt.byteCount) bytes，文件为 \(receipt.filename)。"
        } catch {
            message = nil
            errorMessage = error.localizedDescription
        }
    }

    private func exportLocalBackup() {
        do {
            exportDocument = AccountingFileDocument(data: try backupData())
            exportName = BackupFilename.localFilename(scope: scope)
            showingExporter = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
