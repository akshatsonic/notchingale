import SwiftUI

/// Muted/pastel palette + shared corner-radius constants used across every card.
enum Theme {
    static let windowBackground = Color(red: 0.07, green: 0.07, blue: 0.08)

    // Lightened slightly from the first pass to match the airier pastel
    // tone in the reference screenshots.
    static let taskCard = Color(red: 0.72, green: 0.80, blue: 0.70)
    static let timerCard = Color(red: 0.75, green: 0.69, blue: 0.85)
    static let notepadCard = Color(red: 0.82, green: 0.74, blue: 0.42)
    static let eventsCard = Color(red: 0.55, green: 0.63, blue: 0.73)

    static let cardTextPrimary = Color.black.opacity(0.82)
    static let cardTextSecondary = Color.black.opacity(0.52)

    static let cardRadius: CGFloat = 20
    static let outerRadius: CGFloat = 24
    static let controlRadius: CGFloat = 12
}

/// A frosted / vibrancy-style background — used for the dashboard window
/// itself (a dark HUD-style blur) rather than a plain solid fill, closer
/// to the reference's translucent housing.
struct VibrantBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

/// Procedural paper-grain texture — a fixed-seed scatter of tiny
/// semi-transparent dots, drawn once per card. This approximates the
/// subtle noise/grain overlay in the reference without needing an actual
/// texture asset file (which isn't something this environment can source
/// or verify visually). Apply with `.overlay(NoiseTexture())`.
struct NoiseTexture: View {
    var opacity: Double = 0.05

    var body: some View {
        Canvas { context, size in
            var generator = SeededGenerator(seed: 42)
            let dotCount = Int((size.width * size.height) / 9)
            for _ in 0..<dotCount {
                let x = CGFloat.random(in: 0...size.width, using: &generator)
                let y = CGFloat.random(in: 0...size.height, using: &generator)
                let isDark = Bool.random(using: &generator)
                let alpha = Double.random(in: 0.02...0.05, using: &generator)
                let rect = CGRect(x: x, y: y, width: 1, height: 1)
                context.fill(
                    Path(rect),
                    with: .color((isDark ? Color.black : Color.white).opacity(alpha))
                )
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
    }
}

/// Deterministic RNG so the grain pattern doesn't re-randomize (and
/// visibly shimmer) on every SwiftUI redraw.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

/// A dotted horizontal rule, used below inputs and between task rows in
/// the reference instead of a solid Divider.
struct DottedDivider: View {
    var color: Color = Theme.cardTextSecondary.opacity(0.5)

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
            .overlay(
                GeometryReader { geo in
                    Path { path in
                        let step: CGFloat = 4
                        var x: CGFloat = 0
                        while x < geo.size.width {
                            path.move(to: CGPoint(x: x, y: 0.5))
                            path.addLine(to: CGPoint(x: min(x + 2, geo.size.width), y: 0.5))
                            x += step
                        }
                    }
                    .stroke(color, lineWidth: 1)
                }
            )
            .frame(height: 1)
    }
}

/// A rounded rect with only the bottom corners rounded — used for the
/// notch-overlay countdown, which should sit flush against the top edge
/// of the screen (square top, matching the hardware cutout) while its
/// bottom edge is rounded like the reference.
struct BottomRoundedRect: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
            radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
            radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
