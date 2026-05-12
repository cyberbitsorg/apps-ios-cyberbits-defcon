import SwiftUI

struct FactorScoresWidget: View {
    let factors: DefconFactors?

    private let items: [(label: String, keyPath: KeyPath<DefconFactors, Double>, color: Color)] = [
        ("VOLUME",   \.volumeScore,  Color(hex: "ea580c")),
        ("CVE",      \.cveScore,     Color(hex: "dc2626")),
        ("IMPACT",   \.impactScore,  Color(hex: "f59e0b")),
        ("KEYWORDS", \.keywordScore, Color(hex: "3b82f6")),
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(items, id: \.label) { item in
                VStack(spacing: 2) {
                    Text(item.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(String(format: "%.0f", factors?[keyPath: item.keyPath] ?? 0))
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(item.color)
                        Text("/25")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(item.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}
