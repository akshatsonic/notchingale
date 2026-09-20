import SwiftUI
import AppKit

/// The app's icon, used in the top nav and on the trigger pill.
///
/// AppKit's `NSImage` has been able to load SVG files directly since
/// macOS 12 (no asset-catalog "vector" trick required), so this just
/// loads `logo.svg` from the executable's bundled resources at runtime.
/// If that ever fails for some reason, it falls back to an SF Symbol
/// rather than rendering nothing.
struct AppLogo: View {
    var size: CGFloat = 16

    private static let cachedImage: NSImage? = {
        guard let url = Bundle.module.url(forResource: "logo", withExtension: "svg"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        // The SVG's own fill is dark charcoal, which would be nearly
        // invisible against the black pill/nav backgrounds it's used on.
        // Marking it as a template image lets SwiftUI's .foregroundStyle
        // tint it (white, typically) instead of using the baked-in color.
        image.isTemplate = true
        return image
    }()

    var body: some View {
        if let image = Self.cachedImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "bird.fill")
                .font(.system(size: size * 0.8))
                .frame(width: size, height: size)
        }
    }
}
