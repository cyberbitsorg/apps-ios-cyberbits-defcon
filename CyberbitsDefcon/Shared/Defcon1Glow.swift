import SwiftUI

/// Pulsing DEFCON 1 glow — one implementation of the breathing shadow animation,
/// shared by the dashboard gauge and article rows. Call sites pick up to two
/// shadow layers; this modifier owns the animation. Inactive (or zero-layer)
/// usage applies zero-opacity, zero-radius shadows, i.e. no visible glow.
struct Defcon1Glow: ViewModifier {
    struct Layer {
        let onOpacity: Double
        let offOpacity: Double
        let onRadius: CGFloat
        let offRadius: CGFloat
    }

    let active: Bool
    var color: Color = .defcon(2)
    let layers: [Layer]
    @State private var pulse = false

    private static let none = Layer(onOpacity: 0, offOpacity: 0, onRadius: 0, offRadius: 0)

    func body(content: Content) -> some View {
        let applied = active ? layers : []
        let inner = applied.first ?? Self.none
        let outer = applied.count > 1 ? applied[1] : Self.none
        return content
            .shadow(color: color.opacity(pulse ? inner.onOpacity : inner.offOpacity),
                    radius: pulse ? inner.onRadius : inner.offRadius,
                    x: 0, y: 0)
            .shadow(color: color.opacity(pulse ? outer.onOpacity : outer.offOpacity),
                    radius: pulse ? outer.onRadius : outer.offRadius,
                    x: 0, y: 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}
