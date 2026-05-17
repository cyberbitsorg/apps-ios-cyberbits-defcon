import SwiftUI

struct RootView: View {
    let coordinator: FetchCoordinator
    @Environment(AppState.self) private var appState
    @AppStorage("appearance") private var appearanceRaw: Int = AppearanceMode.system.rawValue

    private var colorScheme: ColorScheme? {
        switch AppearanceMode(rawValue: appearanceRaw) ?? .system {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        @Bindable var state = appState
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView {
                List {
                    NavigationLink(value: AppTab.dashboard) {
                        Label("Dashboard", systemImage: "chart.xyaxis.line")
                    }
                    NavigationLink(value: AppTab.articles) {
                        Label("Articles", systemImage: "newspaper")
                    }
                    NavigationLink(value: AppTab.settings) {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                .navigationTitle("Cyberbits")
            } detail: {
                DashboardView(coordinator: coordinator)
            }
            .preferredColorScheme(colorScheme)
        } else {
            TabView(selection: $state.selectedTab) {
                DashboardView(coordinator: coordinator)
                    .tabItem { Label("Dashboard", systemImage: "chart.xyaxis.line") }
                    .tag(AppTab.dashboard)

                ArticlesView(coordinator: coordinator)
                    .tabItem { Label("Articles", systemImage: "newspaper") }
                    .tag(AppTab.articles)

                SettingsView(coordinator: coordinator)
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(AppTab.settings)
            }
            .tint(Color.defcon(appState.defconStatus?.level ?? 5))
            .preferredColorScheme(colorScheme)
        }
    }
}
