import SwiftUI

@MainActor
struct AIServiceSettingsView: View {
    @State private var provider: AIProvider = .poke
    @State private var endpoint = ""
    @State private var model = ""
    @State private var apiKey = ""
    @State private var message: String?
    @State private var errorMessage: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            Section("绯儿 / AI 记账服务") {
                Picker("服务预设", selection: $provider) {
                    ForEach(AIProvider.allCases) { Text($0.rawValue).tag($0) }
                }
                .onChange(of: provider) { _, newProvider in load(provider: newProvider) }

                Text(provider.configurationHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("HTTPS Endpoint", text: $endpoint)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                TextField("Model 名称", text: $model)
                    .textInputAutocapitalization(.never)
                SecureField("API Key（仅保存至 Keychain）", text: $apiKey)
            }

            Section("连接与安全") {
                Text("每个服务预设单独保存 Endpoint、Model 和 API Key。API Key 统一保存在系统 Keychain；普通应用设置只保存服务商和非敏感配置。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("保存当前服务配置", action: save)
                Button { Task { await testConnection() } } label: {
                    if isTesting { HStack { ProgressView(); Text("正在测试连接") } }
                    else { Label("测试 \(provider.rawValue) 连接", systemImage: "checkmark.icloud") }
                }
                .disabled(isTesting)
            }

            if let message { Section { Text(message).foregroundStyle(.green) } }
            if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
        }
        .navigationTitle("绯儿 / AI 记账服务")
        .onAppear { AIConfigurationStore.migrateLegacyCredential(); load(provider: AIConfigurationStore.selectedProvider()) }
    }

    private func load(provider: AIProvider) {
        self.provider = provider
        endpoint = AIConfigurationStore.endpoint(for: provider)
        model = AIConfigurationStore.model(for: provider)
        apiKey = AIConfigurationStore.apiKey(for: provider)
        message = nil
        errorMessage = nil
    }

    private func save() {
        do {
            try AIConfigurationStore.save(provider: provider, endpointText: endpoint, model: model, apiKey: apiKey)
            errorMessage = nil
            message = "\(provider.rawValue) 配置已安全保存。"
        } catch {
            message = nil
            errorMessage = error.localizedDescription
        }
    }

    private func testConnection() async {
        do {
            try AIConfigurationStore.save(provider: provider, endpointText: endpoint, model: model, apiKey: apiKey)
            isTesting = true
            defer { isTesting = false }
            message = try await AIBookkeepingManager().testConnection(provider: provider)
            errorMessage = nil
        } catch {
            message = nil
            errorMessage = error.localizedDescription
        }
    }
}
