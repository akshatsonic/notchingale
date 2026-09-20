#!/bin/bash
# Builds Notchingale in release mode and packages it as Notchingale.app
# Usage: ./build_app.sh
set -euo pipefail

APP_NAME="Notchingale"
BUILD_DIR=".build/release"

echo "Building ${APP_NAME} (release)…"
swift build -c release

APP_BUNDLE="${APP_NAME}.app"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Info.plist "${APP_BUNDLE}/Contents/Info.plist"

# SwiftPM generates a resource bundle for any target with a `resources:`
# entry (here, the bundled logo.svg) — named "<package>_<target>.bundle"
# and dropped in the build output directory. It has to be copied into
# Contents/Resources/ too, or Bundle.module can't find it at runtime and
# the logo silently falls back to the placeholder SF Symbol.
RESOURCE_BUNDLE="${BUILD_DIR}/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "${RESOURCE_BUNDLE}" ]; then
    cp -R "${RESOURCE_BUNDLE}" "${APP_BUNDLE}/Contents/Resources/"
else
    echo "Warning: expected resource bundle not found at ${RESOURCE_BUNDLE} — the logo won't render."
fi

# Generate an actual .icns app icon from the SVG logo. This matters for
# more than just the Dock/Finder icon — macOS notification banners pull
# their icon from the app bundle's real CFBundleIconFile, not from
# anything the app itself renders in its own UI at runtime, so without
# this notifications show a generic fallback icon instead of the logo.
echo "Generating AppIcon.icns from the logo…"
ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
mkdir -p "${ICONSET_DIR}"

MAKE_ICON_SCRIPT="$(mktemp).swift"
cat > "${MAKE_ICON_SCRIPT}" << 'SWIFT_EOF'
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let image = NSImage(contentsOfFile: args[1]) else {
    print("make-icon: could not load source image")
    exit(1)
}
let outputDir = args[2]
let srcSize = image.size

let targets: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]

for (pixelSize, filename) in targets {
    let canvas = NSSize(width: pixelSize, height: pixelSize)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixelSize, pixelsHigh: pixelSize,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { continue }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Aspect-fit the source (the logo's viewBox isn't square) centered
    // in the square canvas, rather than stretching it to fill — a
    // straight fill would visibly squash the bird shape.
    let scale = min(canvas.width / srcSize.width, canvas.height / srcSize.height)
    let drawnSize = NSSize(width: srcSize.width * scale, height: srcSize.height * scale)
    let origin = NSPoint(x: (canvas.width - drawnSize.width) / 2, y: (canvas.height - drawnSize.height) / 2)
    image.draw(in: NSRect(origin: origin, size: drawnSize), from: NSRect(origin: .zero, size: srcSize), operation: .copy, fraction: 1.0)

    NSGraphicsContext.restoreGraphicsState()

    if let pngData = rep.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: (outputDir as NSString).appendingPathComponent(filename)))
    }
}
SWIFT_EOF

if swift "${MAKE_ICON_SCRIPT}" "Sources/${APP_NAME}/Resources/logo.svg" "${ICONSET_DIR}" \
    && iconutil -c icns "${ICONSET_DIR}" -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"; then
    echo "AppIcon.icns generated."
else
    echo "Warning: icon generation failed — the app will use a generic icon (Dock, Finder, and notifications)."
fi
rm -rf "${ICONSET_DIR}" "${MAKE_ICON_SCRIPT}"

# Ad-hoc code-sign (no paid Apple Developer account needed — this just
# gives the app a stable identity). Without ANY signature, macOS won't
# show the notification-permission dialog at all: UNUserNotificationCenter
# silently returns granted=false with no prompt, no error, nothing to
# debug — a well-known gotcha for unsigned local builds specifically.
# EventKit/Calendar access doesn't have this requirement, which is why
# that permission prompt worked already while notifications didn't.
echo "Ad-hoc signing ${APP_BUNDLE}…"
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "Done. Built ${APP_BUNDLE} — double-click it, or run:"
echo "  open ${APP_BUNDLE}"
echo ""
echo "First launch: right-click > Open (it's ad-hoc signed, not notarized),"
echo "since Gatekeeper will otherwise block an app from an unidentified developer."
