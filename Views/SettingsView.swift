import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("智能记账") {
                    NavigationLink { AIServiceSettingsView() } label: { Label("绯儿 / AI 记账服务", systemImage: "sparkles") }
                    NavigationLink { QuickAddAIView(preferredProvider: .poke) } label: { Label("打开绯儿智能记账", systemImage: "bubble.left.and.bubble.right") }
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
