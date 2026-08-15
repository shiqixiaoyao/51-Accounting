import SwiftUI

struct SettingsView: View {
    @AppStorage("aiProvider") private var aiProvider = AIProvider.poke.rawValue
    @State private var aiEndpoint = UserDefaults.standard.string(forKey: "aiEndpoint") ?? ""
    @State private var aiAPIKey = KeychainService.read("aiAPIKey") ?? ""
    @AppStorage("webDAVEnabled") private var webDAVEnabled = false
    private var selectedProvider: AIProvider { AIProvider(rawValue: aiProvider) ?? .poke }

    var body: some View {
        NavigationStack {
            ZStack { Color.black.ignoresSafeArea(); LinearGradient(colors: [.blue.opacity(0.14), .black], startPoint: .topTrailing, endPoint: .bottomLeading).ignoresSafeArea(); ScrollView { VStack(alignment: .leading, spacing: 18) {
                Text("设置").font(.system(size: 34, weight: .bold, design: .rounded))
                GlassCard(tint: .purple) { VStack(alignment: .leading, spacing: 16) { Label("AI 记账助手", systemImage: "sparkles").font(.headline.weight(.bold)).foregroundStyle(.purple); Text("和绯儿（Fei Er）直接对话，自动匹配账户并生成精确分录。").font(.subheadline).foregroundStyle(.secondary); Picker("服务商", selection: $aiProvider) { ForEach(AIProvider.allCases, id: \.rawValue) { provider in Text(provider.rawValue).tag(provider.rawValue) } }.pickerStyle(.menu); TextField("Poke / OpenAI 兼容 Endpoint（可选）", text: $aiEndpoint).textFieldStyle(.roundedBorder).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().onChange(of: aiEndpoint) { _, newValue in UserDefaults.standard.set(newValue, forKey: "aiEndpoint") }; SecureField("API 密钥（仅安全存储）", text: $aiAPIKey).textFieldStyle(.roundedBorder).onChange(of: aiAPIKey) { _, newValue in KeychainService.write(newValue, for: "aiAPIKey") }; if selectedProvider == .poke && aiEndpoint.isEmpty { Text("未填写 Endpoint 时使用本地安全解析").font(.caption).foregroundStyle(.secondary) } } }
                GlassCard(tint: .cyan) { VStack(alignment: .leading, spacing: 14) { Label("云端备份", systemImage: "icloud.and.arrow.up.fill").font(.headline.weight(.bold)); Toggle("启用 WebDAV", isOn: $webDAVEnabled).tint(.cyan) } }
                NavigationLink { DataManagementView() } label: { GlassCard(tint: .orange) { Label("数据管理", systemImage: "arrow.down.doc.fill").font(.headline.weight(.bold)).foregroundStyle(.orange); Text("导入、导出、备份与恢复账户和交易").font(.subheadline).foregroundStyle(.secondary) } }.buttonStyle(.plain)
            }.padding(18) } }.toolbar(.hidden, for: .navigationBar)
        }
    }
}
