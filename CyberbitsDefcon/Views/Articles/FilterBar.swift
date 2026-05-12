import SwiftUI

struct FilterBar: View {
    @Binding var selectedSource: FeedSource?
    @Binding var unreadOnly: Bool
    @Binding var minLevel: Int?
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
                // Inverted scale: 2 = HIGH or worse (≤ 2), 1 = CRITICAL only
                FilterChip(label: "HIGH+", isSelected: minLevel == 2,
                           accentColor: Color(hex: "ea580c")) { minLevel = minLevel == 2 ? nil : 2 }
                FilterChip(label: "CRITICAL", isSelected: minLevel == 1,
                           accentColor: Color(hex: "dc2626")) { minLevel = minLevel == 1 ? nil : 1 }
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
