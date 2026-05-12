import SwiftUI

struct RootView: View {
    let coordinator: FetchCoordinator
    @Environment(AppState.self) private var appState

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
        } else {
            TabView {
                DashboardView(coordinator: coordinator)
                    .tabItem { Label("Dashboard", systemImage: "chart.xyaxis.line") }

                ArticlesView(coordinator: coordinator)
                    .tabItem { Label("Articles", systemImage: "newspaper") }

                SettingsView(coordinator: coordinator)
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
            .tint(Color.defcon(appState.defconStatus?.level ?? 1))
        }
    }

    private enum Tab: Hashable { case dashboard, articles, settings }
}
