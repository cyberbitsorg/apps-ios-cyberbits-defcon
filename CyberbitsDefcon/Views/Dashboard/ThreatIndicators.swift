import SwiftUI
import SwiftData

/// 2×2 stat-card panel matching docker's "Threat Indicators":
/// apps-docker-cyberbits-defcon/services/frontend/src/App.tsx (StatCard grid).
struct ThreatIndicators: View {
    let status: DefconStatus?
    @Query private var articles: [Article]

    @Environment(\.colorScheme) private var colorScheme
    private var level: Int { status?.level ?? 5 }
    private var levelColor: Color { Color.defconAdaptive(level, in: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THREAT INDICATORS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1.5)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)],
                      spacing: 12) {
                StatCard(label: "Threat Level",
                         value: "DEFCON \(level)",
                         color: levelColor)
                StatCard(label: "Score",
                         value: "\(Int((status?.score ?? 0).rounded()))/100",
                         color: levelColor)
                StatCard(label: "Trend",
                         value: trendText,
                         color: trendColor)
                StatCard(label: "Articles",
                         value: "\(articles.count)",
                         color: .secondary)
            }
        }
        .padding()
        .background(levelColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(levelColor.opacity(0.25), lineWidth: 1))
    }

    private var trendText: String {
        switch status?.trend {
        case .rising:  return "Rising"
        case .falling: return "Falling"
        default:       return "Stable"
        }
    }

    private var trendColor: Color {
        switch status?.trend {
        case .rising:  return Color(hex: "ef4444")
        case .falling: return Color(hex: "22c55e")
        default:       return .secondary
        }
    }
}

private struct StatCard: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .regular))
                .tracking(1)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.adaptiveSurface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.adaptiveBorder.opacity(0.4), lineWidth: 1))
    }
}
