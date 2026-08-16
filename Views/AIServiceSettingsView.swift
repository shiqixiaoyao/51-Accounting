import SwiftUI

@MainActor
struct AIServiceSettingsView: View {
    @State private var provider: AIProvider = .openAICompatible
    @State private var endpoint = ""
    @State private var model = ""
    @State private var apiKey = ""
    @State private var message: String?
    @State private var errorMessage: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            serviceHeaderSection
            serviceConfigurationSection
            connectionSection
            statusSections
        }
        .navigationTitle("AI 记账服务")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            load(provider: AIConfigurationStore.selectedProvider())
        }
    }

    private var serviceHeaderSection: some View {
        Section {
            HStack(spacing: 14) {
                GradientIcon(systemName: "sparkles", colors: [.cyan, .mint])
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.rawValue).font(.headline)
                    Text("配置标准 LLM 服务后，AI 只生成待确认分录.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 5)
        }
        .listRowBackground(Color.clear)
    }

    private var serviceConfigurationSection: some View {
        Section(header: Text("服务配置")) {
            Picker("服务预设", selection: $provider) {
                ForEach(AIProvider.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .onChange(of: provider) { _, newProvider in
                load(provider: newProvider)
            }

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
    }

    private var connectionSection: some View {
        Section(header: Text("连接与安全")) {
            Label("每个预设单独保存 Endpoint、Model 与 API Key。密钥仅保存在系统 Keychain。", systemImage: "lock.shield.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(action: save) {
                Label("保存当前服务配置", systemImage: "checkmark.circle")
            }

            Button(action: runConnectionTest) {
                if isTesting {
                    Label("正在测试连接", systemImage: "arrow.triangle.2.circlepath")
                } else {
                    Label("测试 \(provider.rawValue) 连接", systemImage: "checkmark.icloud")
                }
            }
            .disabled(isTesting)
        }
    }

    @ViewBuilder
    private var statusSections: some View {
        if let message {
            Section {
                InlineStatusCard(text: message, systemImage: "checkmark.circle.fill", tint: .mint)
            }
        }
        if let errorMessage {
            Section {
                InlineStatusCard(text: errorMessage, systemImage: "exclamationmark.triangle.fill", tint: .red)
            }
        }
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

    private func runConnectionTest() {
        Task {
            do {
                try AIConfigurationStore.save(provider: provider, endpointText: endpoint, model: model, apiKey: apiKey)
                isTesting = true
                defer { isTesting = false }
                let manager = AIBookkeepingManager()
                message = try await manager.testConnection(provider: provider)
                errorMessage = nil
            } catch {
                isTesting = false
                message = nil
                errorMessage = error.localizedDescription
            }
        }
    }
}
