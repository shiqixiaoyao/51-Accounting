import SwiftUI
import SwiftData

@MainActor
struct CloudBackupView: View {
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \BookkeepingTransaction.date) private var transactions: [BookkeepingTransaction]

    @AppStorage("webDAVLastBackupTime") private var lastBackupTime = 0.0
    @State private var isEnabled = false
    @State private var endpoint = ""
    @State private var username = ""
    @State private var password = ""
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

            Section("备份操作") {
                Text("上传的是完整 JSON 备份，包含 \(accounts.count) 个账户、\(categories.count) 个分类和 \(transactions.count) 笔交易。上传采用原子 JSON 文件和短暂网络故障重试。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let lastBackupDate {
                    LabeledContent("最近成功备份") {
                        Text(lastBackupDate.formatted(date: .abbreviated, time: .shortened))
                            .monospacedDigit()
                    }
                }

                Button {
                    Task { await testConnection() }
                } label: {
                    actionLabel("测试连接", systemImage: "checkmark.icloud")
                }
                .disabled(isWorking || !isEnabled)

                Button {
                    Task { await uploadBackup() }
                } label: {
                    actionLabel("立即备份到云端", systemImage: "arrow.up.doc")
                }
                .disabled(isWorking || !isEnabled)
            }

            if let message {
                Section { Text(message).foregroundStyle(.green) }
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("云端备份")
        .onAppear(perform: load)
    }

    @ViewBuilder
    private func actionLabel(_ title: String, systemImage: String) -> some View {
        if isWorking {
            HStack { ProgressView(); Text("正在处理") }
        } else {
            Label(title, systemImage: systemImage)
        }
    }

    private func load() {
        WebDAVSettingsStore.migrateLegacyCredential()
        isEnabled = WebDAVSettingsStore.isEnabled()
        endpoint = UserDefaults.standard.string(forKey: "webDAVEndpoint") ?? ""
        username = UserDefaults.standard.string(forKey: "webDAVUsername") ?? ""
        password = KeychainStore.read("webDAVPassword") ?? ""
    }

    private func configuration() throws -> WebDAVConfiguration {
        try WebDAVSettingsStore.makeConfiguration(
            endpointText: endpoint,
            username: username,
            password: password
        )
    }

    private func persistConfiguration() throws -> WebDAVConfiguration {
        let configuration = try configuration()
        try WebDAVSettingsStore.save(
            endpointText: endpoint,
            username: username,
            password: password,
            enabled: isEnabled
        )
        return configuration
    }

    private func testConnection() async {
        do {
            let configuration = try persistConfiguration()
            isWorking = true
            defer { isWorking = false }
            try await BackupManager().testWebDAVConnection(configuration: configuration)
            errorMessage = nil
            message = "WebDAV 连接成功，目录可访问。"
        } catch {
            message = nil
            errorMessage = error.localizedDescription
        }
    }

    private func uploadBackup() async {
        do {
            let configuration = try persistConfiguration()
            let data = try DataTransferService.backup(
                accounts: accounts,
                categories: categories,
                transactions: transactions
            )
            isWorking = true
            defer { isWorking = false }
            let receipt = try await BackupManager().uploadWebDAV(
                data: data,
                filename: "51-accounting-backup-latest.json",
                configuration: configuration
            )
            lastBackupTime = receipt.uploadedAt.timeIntervalSince1970
            errorMessage = nil
            message = "云端备份成功：\(receipt.byteCount) bytes，文件为 \(receipt.filename)。"
        } catch {
            message = nil
            errorMessage = error.localizedDescription
        }
    }
}
