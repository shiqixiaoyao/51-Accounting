import SwiftUI

@MainActor
struct AIServiceSettingsView: View {
    @State private var provider: AIProvider = .poke
    @State private var endpoint = ""
    @State private var apiKey = ""
    @State private var message: String?
    @State private var errorMessage: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            Section("AI 服务") {
                Picker("服务商", selection: $provider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                TextField("HTTPS 服务地址", text: $endpoint)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                SecureField("API 密钥", text: $apiKey)
            }

            Section("连接与安全") {
                Text("服务地址要求使用 HTTPS；仅 localhost 调试可使用 HTTP。API 密钥仅保存到设备钥匙串，不会进入普通应用设置。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("保存配置", action: save)
                Button {
                    Task { await testConnection() }
                } label: {
                    if isTesting {
                        HStack { ProgressView(); Text("正在测试连接") }
                    } else {
                        Label("测试连接", systemImage: "checkmark.icloud")
                    }
                }
                .disabled(isTesting)
            }

            if let message {
                Section { Text(message).foregroundStyle(.green) }
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("AI 记账服务")
        .onAppear(perform: load)
    }

    private func load() {
        AIConfigurationStore.migrateLegacyCredential()
        provider = AIProvider(rawValue: UserDefaults.standard.string(forKey: "aiProvider") ?? "") ?? .poke
        endpoint = UserDefaults.standard.string(forKey: "aiEndpoint") ?? ""
        apiKey = KeychainStore.read("aiAPIKey") ?? ""
    }

    private func save() {
        do {
            try AIConfigurationStore.save(provider: provider, endpointText: endpoint, apiKey: apiKey)
            errorMessage = nil
            message = "AI 服务配置已安全保存。"
        } catch {
            message = nil
            errorMessage = error.localizedDescription
        }
    }

    private func testConnection() async {
        do {
            try AIConfigurationStore.save(provider: provider, endpointText: endpoint, apiKey: apiKey)
            isTesting = true
            defer { isTesting = false }
            let result = try await AIBookkeepingManager().testConnection()
            errorMessage = nil
            message = result
        } catch {
            message = nil
            errorMessage = error.localizedDescription
        }
    }
}
