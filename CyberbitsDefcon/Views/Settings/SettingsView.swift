import SwiftUI
import SwiftData

struct SettingsView: View {
    let coordinator: FetchCoordinator
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    @AppStorage("refreshIntervalMinutes") private var refreshInterval: Int = 60
    @AppStorage("defconNotificationsEnabled") private var defconNotificationsEnabled: Bool = true
    @AppStorage("notificationThreshold") private var notificationThreshold: Int = 3
    @AppStorage("newArticleNotificationsEnabled") private var newArticleNotificationsEnabled: Bool = true
    @AppStorage("appearance") private var appearanceRaw: Int = AppearanceMode.system.rawValue

    var body: some View {
        NavigationStack {
            List {
                Section("Refresh") {
                    Picker("Interval", selection: $refreshInterval) {
                        Text("Every 15 min").tag(15)
                        Text("Every 30 min").tag(30)
                        Text("Every 60 min").tag(60)
                    }
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Refresh Now")
                            if let last = AppSettings.lastRefreshedAt {
                                Text(RelativeTime.format(last))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Never refreshed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            Task { await refresh() }
                        } label: {
                            if appState.isRefreshing {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Refresh", systemImage: "arrow.clockwise")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color(hex: "dc2626"))
                            }
                        }
                        .disabled(appState.isRefreshing)
                        .buttonStyle(.plain)
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appearanceRaw) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode.rawValue)
                        }
                    }
                }

                Section("Notifications") {
                    Toggle("Alert on DEFCON Level Rise", isOn: $defconNotificationsEnabled)
                    if defconNotificationsEnabled {
                        // Inverted scale: threshold is the highest level *number* that still notifies.
                        Picker("Minimum Level", selection: $notificationThreshold) {
                            Text("DEFCON 3 — Round House or worse").tag(3)
                            Text("DEFCON 2 — Fast Pace or worse").tag(2)
                            Text("DEFCON 1 — Cocked Pistol only").tag(1)
                        }
                    }
                    Toggle("Alert on New Articles", isOn: $newArticleNotificationsEnabled)
                }

                Section("About") {
                    LabeledContent("App", value: "Cyberbits Defcon Dashboard")
                    LabeledContent("Version", value: "1.0")
                    if let url = URL(string: "https://cyberbits.systems") {
                        Link(destination: url) {
                            LabeledContent("Developer", value: "Cyberbits Systems")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func refresh() async {
        guard !appState.isRefreshing else { return }
        appState.isRefreshing = true
        appState.defconStatus = await coordinator.runFetchCycle()
        appState.isRefreshing = false
    }
}
