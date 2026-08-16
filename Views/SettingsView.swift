import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        GradientIcon(systemName: "books.vertical.fill", colors: [.cyan, .mint])
                        VStack(alignment: .leading, spacing: 4) {
                            Text("51 记账").font(.headline)
                            Text("复式账本 · 本地优先 · 可选云端备份")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.clear)

                Section(header: Text("智能记账")) {
                    NavigationLink {
                        AIServiceSettingsView()
                    } label: {
                        settingLabel("AI 记账服务", icon: "sparkles", tint: .cyan)
                    }
                    NavigationLink {
                        QuickAddAIView()
                    } label: {
                        settingLabel("打开 AI 智能记账", icon: "wand.and.stars", tint: .mint)
                    }
                }

                Section(header: Text("账户与数据")) {
                    NavigationLink("账户管理") { AccountManagementView() }
                    NavigationLink("分类管理") { CategoryManagementView() }
                    NavigationLink("云端备份") { CloudBackupView() }
                    NavigationLink("数据管理") { DataManagementView() }
                }
            }
            .navigationTitle("设置")
        }
    }

    private func settingLabel(_ title: String, icon: String, tint: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(tint)
        }
    }
}
