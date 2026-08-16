import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingAdd = false
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView(showingAdd: $showingAdd)
                    .tabItem { Label("概览", systemImage: "chart.bar.xaxis") }
                    .tag(0)
                SettingsView()
                    .tabItem { Label("设置", systemImage: "slider.horizontal.3") }
                    .tag(1)
            }
            Button { showingAdd = true } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(width: 62, height: 62)
                    .background(LinearGradient(colors: [.cyan, .mint], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                    .shadow(color: .cyan.opacity(0.35), radius: 16, y: 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("新增记账")
            .offset(y: -18)
        }
        .tint(.cyan)
        .preferredColorScheme(.dark)
        .fontDesign(.rounded)
        .sheet(isPresented: $showingAdd) { QuickAddAIView() }
        .onAppear(perform: applyPendingShortcutRoute)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { applyPendingShortcutRoute() }
        }
    }

    private func applyPendingShortcutRoute() {
        guard let route = ShortcutRouteStore.consume() else { return }
        switch route {
        case .addTransaction, .aiAccounting: showingAdd = true
        }
    }
}

struct AppBackdrop: View {
    let accent: Color
    var body: some View {
        ZStack {
            Color.black
            LinearGradient(colors: [accent.opacity(0.17), .indigo.opacity(0.08), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [accent.opacity(0.10), .clear], center: .topTrailing, startRadius: 8, endRadius: 380)
        }.ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    private let content: Content
    private let tint: Color
    init(tint: Color = .white, @ViewBuilder content: () -> Content) { self.tint = tint; self.content = content() }
    var body: some View {
        content.padding(18)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(LinearGradient(colors: [tint.opacity(0.34), .white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1) }
            .shadow(color: tint.opacity(0.10), radius: 18, y: 10)
    }
}

struct GradientIcon: View {
    let systemName: String
    let colors: [Color]
    var body: some View {
        Image(systemName: systemName).font(.system(size: 18, weight: .semibold)).symbolRenderingMode(.palette).foregroundStyle(colors.first ?? .white, colors.dropFirst().first ?? .cyan).frame(width: 42, height: 42).background(LinearGradient(colors: colors.map { $0.opacity(0.26) }, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String
    var isDisabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16).foregroundStyle(.black).background(LinearGradient(colors: [.cyan, .mint], startPoint: .leading, endPoint: .trailing), in: Capsule())
        }.buttonStyle(.plain).opacity(isDisabled ? 0.42 : 1).disabled(isDisabled)
    }
}

struct InlineStatusCard: View {
    let text: String
    let systemImage: String
    let tint: Color
    var body: some View {
        Label(text, systemImage: systemImage).font(.subheadline.weight(.medium)).foregroundStyle(tint).frame(maxWidth: .infinity, alignment: .leading).padding(14).background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 14, style: .continuous)).overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(tint.opacity(0.30), lineWidth: 1) }
    }
}
