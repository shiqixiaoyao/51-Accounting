import SwiftUI

/// 应用主界面：以沉浸式深色底色和原生 Tab bar 承载核心功能。
struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("概览", systemImage: "chart.bar.xaxis") }
            QuickAddAIView()
                .tabItem { Label("记账", systemImage: "sparkles") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "slider.horizontal.3") }
        }
        .tint(.cyan)
        .preferredColorScheme(.dark)
        .fontDesign(.rounded)
    }
}

struct GlassCard<Content: View>: View {
    private let content: Content
    private let tint: Color

    init(tint: Color = .white, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(LinearGradient(colors: [tint.opacity(0.28), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
    }
}

struct GradientIcon: View {
    let systemName: String
    let colors: [Color]

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(colors.first ?? .white, colors.dropFirst().first ?? .cyan)
            .frame(width: 42, height: 42)
            .background(LinearGradient(colors: colors.map { $0.opacity(0.25) }, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
