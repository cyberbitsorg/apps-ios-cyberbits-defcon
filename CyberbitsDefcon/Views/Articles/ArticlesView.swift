import SwiftUI
import SwiftData

struct ArticlesView: View {
    let coordinator: FetchCoordinator
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @State private var selectedSource: FeedSource? = nil
    @State private var unreadOnly = false
    @State private var minLevel: Int? = nil
    @State private var searchText = ""

    @Query(sort: \Article.publishedAt, order: .reverse) private var allArticles: [Article]

    private var filtered: [Article] {
        allArticles.filter { article in
            if let source = selectedSource, article.sourceRaw != source.rawValue { return false }
            if unreadOnly && article.isRead { return false }
            if let lvl = minLevel, scoreLevel(article.defconScore) < lvl { return false }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                if !article.title.lowercased().contains(q) &&
                   !article.summary.lowercased().contains(q) { return false }
            }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FilterBar(selectedSource: $selectedSource, unreadOnly: $unreadOnly,
                          minLevel: $minLevel, searchText: $searchText)
                    .padding(.vertical, 8)

                List {
                    ForEach(filtered) { article in
                        ArticleRow(article: article) {
                            toggleRead(article)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .refreshable { await refresh() }
            }
            .navigationTitle("Articles")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search threats...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark All Read") { markAllRead() }
                        .font(.caption)
                }
            }
        }
    }

    private func toggleRead(_ article: Article) {
        article.isRead.toggle()
        article.readAt = article.isRead ? Date() : nil
        try? context.save()
    }

    private func markAllRead() {
        filtered.forEach { $0.isRead = true; $0.readAt = Date() }
        try? context.save()
    }

    private func refresh() async {
        guard !appState.isRefreshing else { return }
        appState.isRefreshing = true
        appState.defconStatus = await coordinator.runFetchCycle()
        appState.isRefreshing = false
    }

    private func scoreLevel(_ score: Double) -> Int {
        switch score {
        case 80...: return 5; case 60..<80: return 4; case 40..<60: return 3
        case 20..<40: return 2; default: return 1
        }
    }
}
