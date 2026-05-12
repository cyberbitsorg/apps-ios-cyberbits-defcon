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

    @Query(sort: \Article.publishedAt, order: .reverse) private var articles: [Article]

    private var cves: [String] {
        let pattern = try? NSRegularExpression(pattern: #"CVE-\d{4}-\d{4,}"#, options: .caseInsensitive)
        var seen = Set<String>(); var result: [String] = []
        for article in articles.prefix(50) {
            let text = "\(article.title) \(article.summary)"
            let range = NSRange(text.startIndex..., in: text)
            (pattern?.matches(in: text, range: range) ?? []).forEach {
                if let r = Range($0.range, in: text) {
                    let cve = String(text[r]).uppercased()
                    if seen.insert(cve).inserted { result.append(cve) }
                }
            }
            if result.count >= 10 { break }
        }
        return result
    }

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
                                Text(last, style: .relative)
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

                if !cves.isEmpty {
                    Section("Recent CVEs") {
                        ForEach(cves.prefix(10), id: \.self) { cve in
                            if let url = URL(string: "https://nvd.nist.gov/vuln/detail/\(cve)") {
                                Link(cve, destination: url)
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(Color(hex: "3b82f6"))
                            }
                        }
                    }
                }

                Section("About") {
                    LabeledContent("App", value: "Cyberbits DEFCON")
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("Backend", value: "Standalone — no account needed")
                    LabeledContent("Sources", value: "\(FeedSource.allCases.count) security feeds")
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
