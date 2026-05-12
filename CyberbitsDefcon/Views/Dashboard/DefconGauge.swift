import SwiftUI
import Charts
import SwiftData

struct DefconGauge: View {
    let status: DefconStatus?
    @Query(sort: \DefconHistory.computedAt, order: .forward) private var history: [DefconHistory]

    private var level: Int { status?.level ?? 1 }
    private var color: Color { Color.defcon(level) }
    private var progress: Double { Double(level) / 5.0 }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)

                VStack(spacing: 2) {
                    Text("\(level)")
                        .font(.system(size: 52, weight: .bold, design: .monospaced))
                        .foregroundStyle(color)
                    Text(status?.label ?? "—")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                        .tracking(2)
                }
            }
            .frame(width: 140, height: 140)

            HStack(spacing: 4) {
                Image(systemName: trendIcon)
                    .font(.caption)
                Text(trendText)
                    .font(.caption)
            }
            .foregroundStyle(color)

            if !history.isEmpty {
                Chart(history) { entry in
                    AreaMark(x: .value("Time", entry.computedAt),
                             y: .value("Score", entry.score))
                        .foregroundStyle(color.opacity(0.2))
                    LineMark(x: .value("Time", entry.computedAt),
                             y: .value("Score", entry.score))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...100)
                .frame(height: 40)
            }
        }
        .padding()
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.25), lineWidth: 1))
    }

    private var trendIcon: String {
        switch status?.trend {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    private var trendText: String {
        switch status?.trend {
        case .rising: return "RISING"
        case .falling: return "FALLING"
        default: return "STABLE"
        }
    }
}

#Preview {
    let factors = DefconFactors(volumeScore: 20, cveScore: 18, impactScore: 12, keywordScore: 10)
    let status = DefconStatus(factors: factors, trend: .rising, computedAt: Date())
    return DefconGauge(status: status)
        .padding()
        .background(Color.defconBackground)
}
