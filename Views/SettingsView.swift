import SwiftUI

/// 中文设置页面，统一显示 AI、备份和导出选项。
struct SettingsView: View {
    @AppStorage("aiProvider") private var aiProvider = AIProvider.openAICompatible.rawValue
    @AppStorage("webDAVEnabled") private var webDAVEnabled = false

    var body: some View {
        NavigationStack {
            Form {
                Section("AI 引擎") {
                    Picker("服务商", selection: $aiProvider) {
                        ForEach(AIProvider.allCases, id: \.rawValue) {
                            Text($0.rawValue).tag($0.rawValue)
                        }
                    }
                    SecureField("API 密钥（请使用钥匙串）", text: .constant(""))
                }
                Section("云端备份") {
                    Toggle("启用 WebDAV", isOn: $webDAVEnabled)
                    Label("支持 WebDAV、GitHub 自动提交和 iCloud Drive", systemImage: "cloud")
                }
                Section("导出") {
                    Text("支持 Beancount 纯文本复式记账格式")
                }
            }
            .navigationTitle("设置")
        }
    }
}
