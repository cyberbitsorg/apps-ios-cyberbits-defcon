import SwiftUI

/// v2 breakdown widget: shows the weighted-max contribution (the driver of the
/// current global score), the volume bonus, and the matched trigger (if any).
struct FactorScoresWidget: View {
    let breakdown: DefconBreakdown?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                metricCell(
                    label: "WEIGHTED MAX",
                    value: breakdown?.weightedMax ?? 0,
                    cap: 100,
                    color: Color(hex: "ea580c")
                )
                metricCell(
                    label: "VOLUME BONUS",
                    value: breakdown?.volumeBonus ?? 0,
                    cap: 10,
                    color: Color(hex: "3b82f6")
                )
            }

            if let trigger = breakdown?.trigger {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRIGGER")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color(hex: "dc2626"))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trigger.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                            if let title = breakdown?.triggerArticleTitle {
                                Text(title)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(hex: "dc2626").opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricCell(label: String, value: Double, cap: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", value))
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(color)
                Text("/\(Int(cap))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}
