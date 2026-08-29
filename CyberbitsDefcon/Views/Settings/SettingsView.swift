import SwiftUI
import SwiftData

struct SettingsView: View {
    let coordinator: FetchCoordinator
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    @AppStorage(AppSettings.Keys.refreshIntervalMinutes) private var refreshInterval = AppSettings.defaultRefreshIntervalMinutes
    @AppStorage(AppSettings.Keys.defconNotificationsEnabled) private var defconNotificationsEnabled = true
    @AppStorage(AppSettings.Keys.notificationThreshold) private var notificationThreshold = AppSettings.defaultNotificationThreshold
    @AppStorage(AppSettings.Keys.newArticleNotificationsEnabled) private var newArticleNotificationsEnabled = true
    @AppStorage(AppSettings.Keys.appearance) private var appearanceRaw = AppearanceMode.system.rawValue

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
                            Task { await appState.refresh(using: coordinator) }
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
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
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
}
