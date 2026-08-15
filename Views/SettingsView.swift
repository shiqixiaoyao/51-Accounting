import SwiftUI

struct SettingsView: View {
    @AppStorage("aiProvider") private var aiProvider = AIProvider.poke.rawValue
    @State private var aiEndpoint = ""
    @State private var aiAPIKey = ""
    @AppStorage("webDAVEnabled") private var webDAVEnabled = false

    var body: some View {
        NavigationStack {
            Form {
                Section("AI 记账助手") {
                    Picker("服务商", selection: $aiProvider) {
                        ForEach(AIProvider.allCases, id: \.rawValue) { provider in
                            Text(provider.rawValue).tag(provider.rawValue)
                        }
                    }
                    TextField("Endpoint（可选）", text: $aiEndpoint)
                    SecureField("API 密钥（仅安全存储）", text: $aiAPIKey)
                }

                Section("账户与数据") {
                    NavigationLink("账户管理") {
                        AccountManagementView()
                    }
                    NavigationLink("数据管理") {
                        DataManagementView()
                    }
                }

                Section("云端备份") {
                    Toggle("启用 WebDAV", isOn: $webDAVEnabled)
                }
            }
            .navigationTitle("设置")
        }
        .onAppear {
            migrateLegacyCredentials()
            aiEndpoint = UserDefaults.standard.string(forKey: "aiEndpoint") ?? ""
            aiAPIKey = KeychainStore.read("aiAPIKey") ?? ""
        }
        .onChange(of: aiEndpoint) { _, value in
            UserDefaults.standard.set(value, forKey: "aiEndpoint")
        }
        .onChange(of: aiAPIKey) { _, value in
            try? KeychainStore.write(value, for: "aiAPIKey")
        }
    }

    private func migrateLegacyCredentials() {
        if let legacy = UserDefaults.standard.string(forKey: "aiAPIKey"), KeychainStore.read("aiAPIKey") == nil {
            try? KeychainStore.write(legacy, for: "aiAPIKey")
        }
        UserDefaults.standard.removeObject(forKey: "aiAPIKey")
        UserDefaults.standard.removeObject(forKey: "webDAVPassword")
        UserDefaults.standard.removeObject(forKey: "githubToken")
    }
}
