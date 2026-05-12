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
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView {
                List {
                    NavigationLink(value: Tab.dashboard) {
                        Label("Dashboard", systemImage: "chart.xyaxis.line")
                    }
                    NavigationLink(value: Tab.articles) {
                        Label("Articles", systemImage: "newspaper")
                    }
                    NavigationLink(value: Tab.settings) {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                .navigationTitle("Cyberbits")
            } detail: {
                DashboardView(coordinator: coordinator)
            }
            .preferredColorScheme(colorScheme)
        } else {
            TabView {
                DashboardView(coordinator: coordinator)
                    .tabItem { Label("Dashboard", systemImage: "chart.xyaxis.line") }

                ArticlesView(coordinator: coordinator)
                    .tabItem { Label("Articles", systemImage: "newspaper") }

                SettingsView(coordinator: coordinator)
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
            .tint(Color.defcon(appState.defconStatus?.level ?? 5))
            .preferredColorScheme(colorScheme)
        }
    }

    private enum Tab: Hashable { case dashboard, articles, settings }
}
