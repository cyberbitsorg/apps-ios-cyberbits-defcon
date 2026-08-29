import SwiftUI
import SwiftData
import BackgroundTasks

enum AppTab: Hashable { case dashboard, articles, settings }

@Observable
final class AppState {
    var defconStatus: DefconStatus?
    var isRefreshing = false
    var selectedTab: AppTab = .dashboard
    /// Active severity filter for the Articles screen (exact DEFCON level, 1–5).
    /// Set by tapping a bar in SeverityBreakdown; cleared by FilterBar chips.
    var articleSeverityFilter: Int? = nil
    var articleSourceFilter: FeedSource? = nil

    /// Shared manual-refresh path for Dashboard / Articles / Settings — one
    /// implementation instead of three copy-pasted guards.
    func refresh(using coordinator: FetchCoordinator) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defconStatus = await coordinator.runFetchCycle()
        isRefreshing = false
    }
}

@main
struct CyberbitsDefconApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let container: ModelContainer
    let coordinator: FetchCoordinator
    let appState = AppState()

    init() {
        let schema = Schema([
            Article.self, DefconHistory.self, DedupRecord.self,
            CVERecord.self, StickyLevelRecord.self, VolumeRecord.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let c: ModelContainer
        do {
            c = try ModelContainer(for: schema, configurations: config)
        } catch {
            // Schema-incompatible store from a previous version — wipe and recreate.
            // SwiftData stores live in Application Support; remove and retry.
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let candidates = ["default.store", "default.store-shm", "default.store-wal"]
                for name in candidates {
                    try? FileManager.default.removeItem(at: appSupport.appendingPathComponent(name))
                }
            }
            c = try! ModelContainer(for: schema, configurations: config)
        }
        container = c
        coordinator = FetchCoordinator(modelContainer: c)

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: FetchCoordinator.backgroundTaskID,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Task {
                let coord = FetchCoordinator(modelContainer: c)
                _ = await coord.runFetchCycle()
                refreshTask.setTaskCompleted(success: true)
                FetchCoordinator.scheduleBackgroundRefresh()
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: coordinator)
                .modelContainer(container)
                .environment(appState)
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task {
                        if let status = await coordinator.tickStickyLevel() {
                            appState.defconStatus = status
                        }
                    }
                }
                .task {
                    await NotificationScheduler.requestPermission()
                    if AppSettings.needsRefresh {
                        await appState.refresh(using: coordinator)
                    } else {
                        // No fetch needed, but the sticky-level floor may still
                        // need to decay based on elapsed time alone.
                        if let ticked = await coordinator.tickStickyLevel() {
                            appState.defconStatus = ticked
                        } else {
                            appState.defconStatus = await MainActor.run {
                                try? DefconStore.currentStatus(context: container.mainContext)
                            }
                        }
                    }
                    FetchCoordinator.scheduleBackgroundRefresh()
                }
        }
    }
}
