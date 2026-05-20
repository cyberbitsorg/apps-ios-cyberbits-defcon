import SwiftUI
import Charts
import SwiftData

/// Speedometer-style gauge matching apps-docker-cyberbits-defcon/services/frontend/src/components/defcon/DefconGauge.tsx
/// 240° sweep, 5 coloured segments (blue→white), needle pointing at current score.
struct DefconGauge: View {
    let status: DefconStatus?
    @Query(sort: \DefconHistory.computedAt, order: .forward) private var history: [DefconHistory]

    private var level: Int { status?.level ?? 5 }
    private var color: Color { Color.defcon(level) }
    private var score: Double { status?.score ?? 0 }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("CYBERSECURITY DEFCON")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: trendIcon).font(.caption2)
                    Text(trendText).font(.caption2)
                }
                .foregroundStyle(color)
            }

            GaugeArc(level: level, score: score)
                .frame(height: 165)
                .frame(maxWidth: 280)
                .accessibilityLabel("DEFCON \(level): \(status?.label ?? "")")

            if let trigger = status?.breakdown.trigger {
                driverRow(label: trigger.label, title: status?.breakdown.triggerArticleTitle)
            } else if score == 0 {
                driverRow(label: "No notable threats", title: nil)
            } else {
                driverRow(label: "Elevated", title: "by recent activity")
            }

            if history.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("24h TREND")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
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
        }
        .padding()
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.25), lineWidth: 1))
        .modifier(Defcon1Glow(active: level == 1))
    }

    private func driverRow(label: String, title: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DRIVER")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            (
                Text(label).font(.caption.weight(.semibold)).foregroundColor(color) +
                Text(title.map { ": \($0)" } ?? "").font(.caption).foregroundColor(.secondary)
            )
            .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - SVG-equivalent Canvas gauge

private struct GaugeArc: View {
    let level: Int
    let score: Double
    @Environment(\.colorScheme) private var colorScheme

    /// 240° sweep, 8 o'clock → 4 o'clock (clockwise over the top).
    private static let startDeg: Double = 150
    private static let sweepDeg: Double = 240
    private static let trackWidth: CGFloat = 14
    private static let segmentColors: [Color] = [
        Color(hex: "3b82f6"), // DEFCON 5
        Color(hex: "22c55e"), // DEFCON 4
        Color(hex: "eab308"), // DEFCON 3
        Color(hex: "dc2626"), // DEFCON 2
        Color(hex: "ffffff"), // DEFCON 1
    ]

    var body: some View {
        GeometryReader { geo in
            // viewBox 200×155 → keep aspect ratio
            let size = min(geo.size.width, geo.size.height * (200.0 / 155.0))
            let cx = geo.size.width / 2
            let cy = size * (90.0 / 200.0) + (geo.size.height - size * 155.0 / 200.0) / 2
            let r = size * (78.0 / 200.0)

            ZStack {
                // Background track
                ArcShape(center: CGPoint(x: cx, y: cy), radius: r,
                         startDeg: Self.startDeg, endDeg: Self.startDeg + Self.sweepDeg)
                    .stroke(Color.gray.opacity(0.25),
                            style: StrokeStyle(lineWidth: Self.trackWidth, lineCap: .round))

                // 5 coloured segments (48° each)
                ForEach(0..<5, id: \.self) { i in
                    let s = Self.startDeg + Double(i) * 48
                    ArcShape(center: CGPoint(x: cx, y: cy), radius: r,
                             startDeg: s, endDeg: s + 48)
                        .stroke(Self.segmentColors[i].opacity(0.85),
                                style: StrokeStyle(lineWidth: Self.trackWidth))
                }

                // Score fill overlay — bright arc from start to needle
                ArcShape(center: CGPoint(x: cx, y: cy), radius: r,
                         startDeg: Self.startDeg, endDeg: needleAngleDeg)
                    .stroke(Color.defcon(level).opacity(0.35),
                            style: StrokeStyle(lineWidth: Self.trackWidth, lineCap: .round))
                    .animation(.easeInOut(duration: 0.5), value: score)

                // Needle (triangle pointing from pivot outward)
                NeedleShape(center: CGPoint(x: cx, y: cy), length: r * 0.55,
                            width: 4, angleDeg: needleAngleDeg)
                    .fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.9))
                    .animation(.easeInOut(duration: 0.5), value: score)

                // Pivot
                Circle()
                    .fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.9))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().fill(Color.defcon(level)).frame(width: 6, height: 6))
                    .position(x: cx, y: cy)

                // Text labels — below the pivot, like the original
                VStack(spacing: 0) {
                    Text("\(level)")
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.defconAdaptive(level, in: colorScheme))
                    Text(DefconStatus.labels[level] ?? "—")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(Color.defconAdaptive(level, in: colorScheme).opacity(0.85))
                    Text("\(Int(score.rounded())) / 100")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)
                }
                .position(x: cx, y: cy + r * 0.5)
                .modifier(Defcon1Glow(active: level == 1, mode: .text))
            }
        }
    }

    private var needleAngleDeg: Double {
        Self.startDeg + (min(max(score, 0), 100) / 100) * Self.sweepDeg
    }
}

private struct ArcShape: Shape {
    let center: CGPoint
    let radius: CGFloat
    let startDeg: Double
    let endDeg: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: center,
                 radius: radius,
                 startAngle: .degrees(startDeg),
                 endAngle: .degrees(endDeg),
                 clockwise: false)
        return p
    }
}

private struct NeedleShape: Shape {
    let center: CGPoint
    let length: CGFloat
    let width: CGFloat
    let angleDeg: Double

    func path(in rect: CGRect) -> Path {
        let rad = angleDeg * .pi / 180
        let tip = CGPoint(x: center.x + length * cos(rad), y: center.y + length * sin(rad))
        let perp = rad + .pi / 2
        let left  = CGPoint(x: center.x + width * cos(perp), y: center.y + width * sin(perp))
        let right = CGPoint(x: center.x - width * cos(perp), y: center.y - width * sin(perp))
        var p = Path()
        p.move(to: tip)
        p.addLine(to: left)
        p.addLine(to: right)
        p.closeSubpath()
        return p
    }
}

// MARK: - DEFCON 1 pulse glow

private struct Defcon1Glow: ViewModifier {
    enum Mode { case container, text }
    let active: Bool
    var mode: Mode = .container
    @State private var pulse = false

    func body(content: Content) -> some View {
        if !active {
            content
        } else {
            content
                .shadow(color: Color(hex: "dc2626").opacity(pulse ? 0.95 : 0.4),
                        radius: pulse ? (mode == .text ? 16 : 18) : (mode == .text ? 6 : 8),
                        x: 0, y: 0)
                .shadow(color: Color(hex: "dc2626").opacity(pulse ? 0.6 : 0.25),
                        radius: pulse ? (mode == .text ? 24 : 28) : (mode == .text ? 10 : 14),
                        x: 0, y: 0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
        }
    }
}

#Preview {
    let breakdown = DefconBreakdown(weightedMax: 88, volumeBonus: 0,
                                    trigger: .activeExploitation,
                                    triggerArticleTitle: "Critical RCE exploited in the wild")
    let status = DefconStatus(breakdown: breakdown, trend: .rising, computedAt: Date())
    return DefconGauge(status: status)
        .padding()
        .background(Color.defconBackground)
}
