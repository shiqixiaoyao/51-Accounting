import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("智能记账") {
                    NavigationLink { AIServiceSettingsView() } label: { Label("绯儿 / AI 记账服务", systemImage: "sparkles") }
                    NavigationLink { QuickAddAIView() } label: { Label("打开绯儿智能记账", systemImage: "bubble.left.and.bubble.right") }
                }
                Section("账户与数据") {
                    NavigationLink("账户管理") { AccountManagementView() }
                    NavigationLink("分类管理") { CategoryManagementView() }
                    NavigationLink("云端备份") { CloudBackupView() }
                    NavigationLink("数据管理") { DataManagementView() }
                }
            }
            .navigationTitle("设置")
        }
    }
}

struct AIServiceSettingsView: View {
    @State private var provider: AIProvider = .poke
    @State private var endpoint = AIProvider.poke.defaultEndpoint
    @State private var model = AIProvider.poke.defaultModel
    @State private var apiKey = ""
    @State private var status: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            Section("AI 服务") {
                Picker("服务商", selection: $provider) { ForEach(AIProvider.allCases, id: \\.self) { Text($0.rawValue).tag($0) } }
                TextField("模型名称", text: $model).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("接口地址", text: $endpoint).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("API Key", text: $apiKey)
            }
            Section {
                Button("保存配置") { save() }
                Button(isTesting ? "测试中…" : "测试连接") { test() }.disabled(isTesting)
            }
            if let status { Section { Text(status).foregroundStyle(status.hasPrefix("已连接") ? .green : .red) } }
            Section("说明") { Text("绯儿 / Poke、OpenAI、DeepSeek、Claude 和自定义 OpenAI 兼容接口都可以配置。API Key 只保存到系统钥匙串。").font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle("AI 服务设置")
        .onAppear { load() }
        .onChange(of: provider) { _, newProvider in
            if endpoint.isEmpty { endpoint = newProvider.defaultEndpoint }
            if model.isEmpty { model = newProvider.defaultModel }
        }
    }

    private func load() {
        guard let configuration = try? AIConfigurationStore.load() else { return }
        provider = configuration.provider; endpoint = configuration.endpoint.absoluteString; model = configuration.model; apiKey = configuration.apiKey
    }
    private func save() {
        do { try AIConfigurationStore.save(provider: provider, endpointText: endpoint, apiKey: apiKey, model: model); status = "配置已保存。" }
        catch { status = error.localizedDescription }
    }
    private func test() {
        do { try AIConfigurationStore.save(provider: provider, endpointText: endpoint, apiKey: apiKey, model: model) }
        catch { status = error.localizedDescription; return }
        isTesting = true
        Task { defer { isTesting = false }; do { status = try await AIBookkeepingManager().testConnection() } catch { status = error.localizedDescription } }
    }
}
