import SwiftUI

/// 应用主界面：概览、快速记账和设置。
struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView().tabItem { Label("概览", systemImage: "chart.bar") }
            QuickAddAIView().tabItem { Label("快速记账", systemImage: "plus.circle.fill") }
            SettingsView().tabItem { Label("设置", systemImage: "gear") }
        }
    }
}
