import SwiftUI
import SwiftData
import BackgroundTasks

@Observable
final class AppState {
    var defconStatus: DefconStatus?
    var isRefreshing = false
}

@main
struct CyberbitsDefconApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let container: ModelContainer
    let coordinator: FetchCoordinator
    let appState = AppState()

    init() {
        let schema = Schema([Article.self, DefconHistory.self])
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

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: coordinator)
                .modelContainer(container)
                .environment(appState)
                .task {
                    await NotificationScheduler.requestPermission()
                    if AppSettings.needsRefresh {
                        appState.isRefreshing = true
                        appState.defconStatus = await coordinator.runFetchCycle()
                        appState.isRefreshing = false
                    } else {
                        appState.defconStatus = await MainActor.run {
                            try? DefconStore.currentStatus(context: container.mainContext)
                        }
                    }
                    FetchCoordinator.scheduleBackgroundRefresh()
                }
        }
    }
}
