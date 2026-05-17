import SwiftUI
import SwiftData

struct ArticlesView: View {
    let coordinator: FetchCoordinator
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @State private var unreadOnly = false
    @State private var searchText = ""
    @State private var currentPage = 1

    private static let pageSize = 20

    @Query(sort: \Article.publishedAt, order: .reverse) private var allArticles: [Article]

    private var filtered: [Article] {
        allArticles.filter { article in
            if let source = appState.articleSourceFilter, article.sourceRaw != source.rawValue { return false }
            if unreadOnly && article.isRead { return false }
            // Exact DEFCON level match — mirrors docker's SEVERITY_RANGES filter.
            if let lvl = appState.articleSeverityFilter,
               Scorer.levelFromScore(article.defconScore) != lvl { return false }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                if !article.title.lowercased().contains(q) &&
                   !article.summary.lowercased().contains(q) { return false }
            }
            return true
        }
    }

    private var totalPages: Int { max(1, Int(ceil(Double(filtered.count) / Double(Self.pageSize)))) }

    private var pageArticles: [Article] {
        let start = (currentPage - 1) * Self.pageSize
        guard start < filtered.count else { return [] }
        let end = min(start + Self.pageSize, filtered.count)
        return Array(filtered[start..<end])
    }

    var body: some View {
        @Bindable var state = appState
        NavigationStack {
            VStack(spacing: 0) {
                FilterBar(selectedSource: $state.articleSourceFilter,
                          unreadOnly: $unreadOnly,
                          severityLevel: $state.articleSeverityFilter,
                          searchText: $searchText)
                    .padding(.vertical, 8)
                    .onChange(of: appState.articleSourceFilter)   { _, _ in currentPage = 1 }
                    .onChange(of: unreadOnly)                     { _, _ in currentPage = 1 }
                    .onChange(of: appState.articleSeverityFilter) { _, _ in currentPage = 1 }
                    .onChange(of: searchText)                     { _, _ in currentPage = 1 }

                List {
                    ForEach(pageArticles) { article in
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

                if filtered.count > Self.pageSize {
                    PaginationBar(currentPage: $currentPage, totalPages: totalPages,
                                  totalCount: filtered.count, pageSize: Self.pageSize)
                }
            }
            .navigationTitle("Articles")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search threats...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    let allRead = !filtered.isEmpty && filtered.allSatisfy(\.isRead)
                    Button(allRead ? "Mark all unread" : "Mark all read") {
                        setAllRead(!allRead)
                    }
                    .font(.caption)
                    .disabled(filtered.isEmpty)
                }
            }
        }
    }

    private func toggleRead(_ article: Article) {
        article.isRead.toggle()
        article.readAt = article.isRead ? Date() : nil
        try? context.save()
    }

    private func setAllRead(_ isRead: Bool) {
        let now = Date()
        filtered.forEach {
            $0.isRead = isRead
            $0.readAt = isRead ? now : nil
        }
        try? context.save()
    }

    private func refresh() async {
        guard !appState.isRefreshing else { return }
        appState.isRefreshing = true
        appState.defconStatus = await coordinator.runFetchCycle()
        appState.isRefreshing = false
    }
}

private struct PaginationBar: View {
    @Binding var currentPage: Int
    let totalPages: Int
    let totalCount: Int
    let pageSize: Int

    private var rangeText: String {
        let start = (currentPage - 1) * pageSize + 1
        let end = min(currentPage * pageSize, totalCount)
        return "\(start)–\(end) of \(totalCount)"
    }

    var body: some View {
        HStack {
            Button {
                if currentPage > 1 { currentPage -= 1 }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(currentPage <= 1)

            Spacer()

            VStack(spacing: 0) {
                Text("Page \(currentPage) of \(totalPages)")
                    .font(.caption.weight(.medium))
                Text(rangeText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if currentPage < totalPages { currentPage += 1 }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(currentPage >= totalPages)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.adaptiveSurface)
    }
}
