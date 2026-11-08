import SwiftUI

struct ArticleRow: View {
    let article: Article
    let onToggleRead: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var isDefcon1: Bool { article.defconLevel == 1 }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.defcon(article.defconLevel))
                .frame(width: 3)
                .cornerRadius(2)
                .padding(.vertical, 4)
                .modifier(Defcon1Glow(active: isDefcon1, layers: [
                    .init(onOpacity: 0.9, offOpacity: 0.35, onRadius: 10, offRadius: 4),
                ]))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(article.title)
                        .font(.subheadline.weight(article.isRead ? .regular : .semibold))
                        .foregroundStyle(article.isRead ? .secondary : .primary)
                        .lineLimit(3)
                    Spacer()
                    Text(String(format: "%.0f", article.defconScore))
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(Color.defconAdaptive(article.defconLevel, in: colorScheme))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.defcon(article.defconLevel)
                            .opacity(isDefcon1 ? 0.3 : 0.15),
                                    in: RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color(hex: "dc2626").opacity(isDefcon1 ? 0.6 : 0),
                                        lineWidth: isDefcon1 ? 1 : 0)
                        )
                        .modifier(Defcon1Glow(active: isDefcon1, layers: [
                            .init(onOpacity: 0.7, offOpacity: 0.2, onRadius: 8, offRadius: 3),
                        ]))
                }
                HStack {
                    // Uniform slate-300 badge across all sources — intentional, matches docker fallback.
                    let sourceColor = Color(hex: "cbd5e1")
                    let borderColor = Color.defcon(article.defconLevel)
                    Text(article.source.abbreviation)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(sourceColor)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(sourceColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(borderColor.opacity(0.38), lineWidth: 1))
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
                // Category tags (docker card pills): right-aligned footer line, gray chips.
                if !article.tags.isEmpty {
                    HStack(spacing: 4) {
                        Spacer(minLength: 0)
                        ForEach(article.tags, id: \.self) { tag in
                            Text(Vocabulary.tagDisplayLabels[tag] ?? tag)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.primary.opacity(0.06), in: Capsule())
                        }
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
