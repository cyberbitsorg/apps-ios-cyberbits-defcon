import SwiftUI

struct DashboardView: View {
    let coordinator: FetchCoordinator
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    DefconGauge(status: appState.defconStatus)
                        .padding(.horizontal)

                    ThreatIndicators(status: appState.defconStatus)
                        .padding(.horizontal)

                    TopThreatsWidget()
                        .padding(.horizontal)

                    SeverityBreakdown()
                        .padding(.horizontal)

                    TrendingKeywords()
                        .padding(.horizontal)

                    RecentCVEs()
                        .padding(.horizontal)

                    SourceDistribution()
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.adaptiveBackground)
            .navigationTitle("DEFCON Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await appState.refresh(using: coordinator) }
                    } label: {
                        if appState.isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(appState.isRefreshing)
                }
            }
            .refreshable { await appState.refresh(using: coordinator) }
        }
    }
}
