import SwiftUI

/// Filter chips for the Articles screen.
/// Mirrors apps-docker-cyberbits-defcon: severity = exact DEFCON level (1–5),
/// source = exact feed, plus an iOS-only Unread toggle.
struct FilterBar: View {
    @Binding var selectedSource: FeedSource?
    @Binding var unreadOnly: Bool
    @Binding var severityLevel: Int?
    @Binding var searchText: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All Sources", isSelected: selectedSource == nil) {
                    selectedSource = nil
                }
                ForEach(FeedSource.allCases) { source in
                    FilterChip(label: source.displayName, isSelected: selectedSource == source,
                               accentColor: source.accentColor) {
                        selectedSource = selectedSource == source ? nil : source
                    }
                }

                Divider().frame(height: 20)

                // Exact DEFCON level — matches docker's SEVERITY_RANGES per-level filter.
                ForEach((1...5), id: \.self) { level in
                    FilterChip(label: "DEF \(level)",
                               isSelected: severityLevel == level,
                               accentColor: Color.defcon(level)) {
                        severityLevel = severityLevel == level ? nil : level
                    }
                }

                Divider().frame(height: 20)

                FilterChip(label: "Unread", isSelected: unreadOnly,
                           accentColor: Color(hex: "22c55e")) { unreadOnly.toggle() }
            }
            .padding(.horizontal)
        }
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    var accentColor: Color = Color(hex: "dc2626")
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(isSelected ? accentColor : .secondary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(
                    isSelected ? accentColor.opacity(0.15) : Color.adaptiveSurface,
                    in: Capsule()
                )
                .overlay(Capsule().stroke(isSelected ? accentColor.opacity(0.5) : Color.adaptiveBorder, lineWidth: 1))
        }
    }
}
