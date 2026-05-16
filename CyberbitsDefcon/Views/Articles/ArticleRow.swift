import SwiftUI

struct ArticleRow: View {
    let article: Article
    let onToggleRead: () -> Void
    @State private var pulse = false

    private func scoreLevel(_ score: Double) -> Int { Scorer.levelFromScore(score) }
    private var isDefcon1: Bool { scoreLevel(article.defconScore) == 1 }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.defcon(scoreLevel(article.defconScore)))
                .frame(width: 3)
                .cornerRadius(2)
                .padding(.vertical, 4)
                .shadow(color: isDefcon1 ? Color(hex: "dc2626").opacity(pulse ? 0.9 : 0.35) : .clear,
                        radius: isDefcon1 ? (pulse ? 10 : 4) : 0)
                .onAppear {
                    guard isDefcon1 else { return }
                    withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }

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
                        .background(Color.defcon(scoreLevel(article.defconScore))
                            .opacity(isDefcon1 ? (pulse ? 0.45 : 0.15) : 0.15),
                                    in: RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color(hex: "dc2626").opacity(isDefcon1 ? (pulse ? 0.9 : 0.3) : 0),
                                        lineWidth: isDefcon1 ? 1 : 0)
                        )
                        .shadow(color: isDefcon1 ? Color(hex: "dc2626").opacity(pulse ? 0.7 : 0.2) : .clear,
                                radius: isDefcon1 ? (pulse ? 8 : 3) : 0)
                }
                HStack {
                    Text(article.source.displayName)
                        .font(.caption2)
                        .foregroundStyle(article.source.accentColor)
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(RelativeTime.format(article.publishedAt))
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
