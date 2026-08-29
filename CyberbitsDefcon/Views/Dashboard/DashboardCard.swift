import SwiftUI

/// Shared chrome for dashboard widgets: caption header + surface card.
/// One implementation instead of the same block copy-pasted per widget.
struct DashboardCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.adaptiveSurface, in: RoundedRectangle(cornerRadius: 12))
    }
}
