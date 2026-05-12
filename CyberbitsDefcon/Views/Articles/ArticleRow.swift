import SwiftUI

struct ArticleRow: View {
    let article: Article
    let onToggleRead: () -> Void

    private func scoreLevel(_ score: Double) -> Int {
        switch score {
        case 80...: return 5; case 60..<80: return 4; case 40..<60: return 3
        case 20..<40: return 2; default: return 1
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.defcon(scoreLevel(article.defconScore)))
                .frame(width: 3)
                .cornerRadius(2)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(article.title)
                        .font(.subheadline.weight(article.isRead ? .regular : .semibold))
                        .foregroundStyle(article.isRead ? .secondary : .primary)
                        .lineLimit(3)
                    Spacer()
                    Text(String(format: "%.0f", article.defconScore))
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(Color.defcon(scoreLevel(article.defconScore)))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.defcon(scoreLevel(article.defconScore)).opacity(0.15),
                                    in: RoundedRectangle(cornerRadius: 5))
                }
                HStack {
                    Text(article.source.displayName)
                        .font(.caption2)
                        .foregroundStyle(article.source.accentColor)
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(article.publishedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if article.isRead {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color.adaptiveSurface, in: RoundedRectangle(cornerRadius: 10))
        .opacity(article.isRead ? 0.7 : 1.0)
        .swipeActions(edge: .trailing) {
            Button {
                onToggleRead()
            } label: {
                Label(article.isRead ? "Unread" : "Read",
                      systemImage: article.isRead ? "envelope.badge" : "checkmark")
            }
            .tint(article.isRead ? Color(hex: "3b82f6") : Color(hex: "22c55e"))
        }
    }
}
