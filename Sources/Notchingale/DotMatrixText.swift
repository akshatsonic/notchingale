import SwiftUI

/// Renders text as an old-school 5x7 dot-matrix/LED display, one grid of
/// dots per character — every dot position is drawn (faint if "off",
/// bright if "on"), matching the reference's look where the unlit dots
/// are still faintly visible. This exists instead of a real dot-matrix
/// font file because there's no such asset available to bundle here;
/// drawing the pattern directly in SwiftUI sidesteps that entirely and
/// looks the same either way.
struct DotMatrixText: View {
    let text: String
    var dotSize: CGFloat = 3
    var dotSpacing: CGFloat = 1.4
    var charSpacing: CGFloat = 3
    var onColor: Color = .white
    var offColor: Color = .white.opacity(0.09)

    var body: some View {
        HStack(alignment: .center, spacing: charSpacing) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                DotMatrixGlyph(
                    pattern: DotMatrixFont.pattern(for: character),
                    dotSize: dotSize,
                    dotSpacing: dotSpacing,
                    onColor: onColor,
                    offColor: offColor
                )
            }
        }
    }
}

private struct DotMatrixGlyph: View {
    let pattern: [[Bool]] // rows x columns, true = lit
    let dotSize: CGFloat
    let dotSpacing: CGFloat
    let onColor: Color
    let offColor: Color

    var body: some View {
        VStack(spacing: dotSpacing) {
            ForEach(0..<pattern.count, id: \.self) { row in
                HStack(spacing: dotSpacing) {
                    ForEach(0..<pattern[row].count, id: \.self) { col in
                        Circle()
                            .fill(pattern[row][col] ? onColor : offColor)
                            .frame(width: dotSize, height: dotSize)
                    }
                }
            }
        }
    }
}

/// 5x7 bitmap patterns (7 rows tall, 5 columns wide — 3 wide for the
/// colon) for the digits and punctuation a countdown timer ever needs.
enum DotMatrixFont {
    static func pattern(for character: Character) -> [[Bool]] {
        digitPatterns[character] ?? blank5x7
    }

    private static let blank5x7: [[Bool]] = Array(repeating: Array(repeating: false, count: 5), count: 7)

    private static func rows(_ rows: [String]) -> [[Bool]] {
        rows.map { row in row.map { $0 == "1" } }
    }

    private static let digitPatterns: [Character: [[Bool]]] = [
        "0": rows([
            "01110",
            "10001",
            "10011",
            "10101",
            "11001",
            "10001",
            "01110",
        ]),
        "1": rows([
            "00100",
            "01100",
            "00100",
            "00100",
            "00100",
            "00100",
            "01110",
        ]),
        "2": rows([
            "01110",
            "10001",
            "00001",
            "00010",
            "00100",
            "01000",
            "11111",
        ]),
        "3": rows([
            "11111",
            "00010",
            "00100",
            "00010",
            "00001",
            "10001",
            "01110",
        ]),
        "4": rows([
            "00010",
            "00110",
            "01010",
            "10010",
            "11111",
            "00010",
            "00010",
        ]),
        "5": rows([
            "11111",
            "10000",
            "11110",
            "00001",
            "00001",
            "10001",
            "01110",
        ]),
        "6": rows([
            "00110",
            "01000",
            "10000",
            "11110",
            "10001",
            "10001",
            "01110",
        ]),
        "7": rows([
            "11111",
            "00001",
            "00010",
            "00100",
            "01000",
            "01000",
            "01000",
        ]),
        "8": rows([
            "01110",
            "10001",
            "10001",
            "01110",
            "10001",
            "10001",
            "01110",
        ]),
        "9": rows([
            "01110",
            "10001",
            "10001",
            "01111",
            "00001",
            "00010",
            "01100",
        ]),
        ":": rows([
            "000",
            "000",
            "010",
            "000",
            "010",
            "000",
            "000",
        ]),
    ]
}
