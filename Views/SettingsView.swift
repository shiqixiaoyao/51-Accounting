import SwiftUI

struct SettingsView: View {
    @AppStorage("aiProvider") private var aiProvider = AIProvider.poke.rawValue
    @AppStorage("aiEndpoint") private var aiEndpoint = ""
    @AppStorage("aiAPIKey") private var aiAPIKey = ""
    @AppStorage("webDAVEnabled") private var webDAVEnabled = false

    private var selectedProvider: AIProvider { AIProvider(rawValue: aiProvider) ?? .poke }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                LinearGradient(colors: [.blue.opacity(0.14), .black], startPoint: .topTrailing, endPoint: .bottomLeading).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("设置").font(.system(size: 34, weight: .bold, design: .rounded))
                        GlassCard(tint: .purple) {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("AI 记账助手", systemImage: "sparkles").font(.headline.weight(.bold)).foregroundStyle(.purple)
                                Text("和绯儿（Fei Er）直接对话，自动匹配账户并生成精确分录。").font(.subheadline).foregroundStyle(.secondary)
                                Picker("服务商", selection: $aiProvider) {
                                    ForEach(AIProvider.allCases, id: \.rawValue) { provider in Text(provider.rawValue).tag(provider.rawValue) }
                                }.pickerStyle(.menu)
                                TextField("Poke / OpenAI 兼容 Endpoint（可选）", text: $aiEndpoint).textFieldStyle(.roundedBorder).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                                SecureField("API 密钥（可选）", text: $aiAPIKey).textFieldStyle(.roundedBorder)
                                if selectedProvider == .poke && aiEndpoint.isEmpty {
                                    Text("未填写 Endpoint 时使用本地安全解析；如有 Poke webhook 或兼容接口，请粘贴地址即可。").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        GlassCard(tint: .cyan) {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("云端备份", systemImage: "icloud.and.arrow.up.fill").font(.headline.weight(.bold)).foregroundStyle(.cyan)
                                Toggle("启用 WebDAV", isOn: $webDAVEnabled).tint(.cyan)
                                Label("支持 WebDAV、GitHub 自动提交和 iCloud Drive", systemImage: "checkmark.shield.fill").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        GlassCard(tint: .orange) {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("导出", systemImage: "square.and.arrow.up.fill").font(.headline.weight(.bold)).foregroundStyle(.orange)
                                Text("支持 Beancount 纯文本复式记账格式").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }.padding(18)
                }
            }.toolbar(.hidden, for: .navigationBar)
        }
    }
}
