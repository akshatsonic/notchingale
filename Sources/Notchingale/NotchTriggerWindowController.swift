import AppKit
import SwiftUI

/// A small borderless panel pinned to the top-center of the screen (right
/// where a physical notch sits). Unlike NSStatusItem, this never asks the
/// real system menu bar for a slot, so a crowded menu bar full of
/// third-party icons can't push it into an invisible overflow area — it's
/// just our own window, drawn on top of everything at a fixed position.
final class NotchTriggerWindowController: NSWindowController {

    private let onHoverChanged: (Bool) -> Void
    private let onRightClick: (NSView) -> Void

    private let idleSize = NSSize(width: 132, height: 26)

    /// While a timer is running, the pill widens to a "universal safe"
    /// notch width (215pt comfortably covers M1–M3 MacBook Air/Pro notch
    /// widths — Apple doesn't expose the actual notch width via any
    /// public API) and grows tall enough to clear the real notch cutout.
    /// The height IS computed from a real API — `NSScreen.safeAreaInsets.top`
    /// reports the actual unusable inset for the current display — rather
    /// than a guessed constant, with a fallback for displays with no notch.
    private var expandedSize: NSSize {
        let notchHeight = (NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main)?
            .safeAreaInsets.top ?? 32
        // Extra room below the actual cutout so the digits are clearly
        // clear of it, not sitting right at the edge.
        let clearance: CGFloat = 24
        return NSSize(width: 215, height: max(notchHeight + clearance, idleSize.height))
    }

    /// Tracks which size is currently "wanted" so a display change (e.g.
    /// plugging in a monitor) can reposition using the right size, not
    /// just reset to idle.
    private var currentSize: NSSize

    init(onHoverChanged: @escaping (Bool) -> Void, onRightClick: @escaping (NSView) -> Void) {
        self.onHoverChanged = onHoverChanged
        self.onRightClick = onRightClick
        self.currentSize = NSSize(width: 132, height: 26)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 132, height: 26)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = false

        super.init(window: panel)

        let hoverView = HoverableHostingView(
            rootView: TriggerPillView(),
            onHoverChanged: onHoverChanged,
            onRightClick: onRightClick
        )
        panel.contentView = hoverView

        setFrame(size: idleSize, animated: false)

        // Displays get connected/disconnected, resolutions change, the
        // menu bar can move to a different screen — any of that leaves a
        // window positioned with absolute coordinates from the *old*
        // arrangement stranded wherever that used to be. Recompute
        // whenever the system tells us the screen layout changed.
        NotificationCenter.default.addObserver(
            self, selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc private func screenParametersChanged() {
        // A brief delay: right after a screen reconfiguration, NSScreen's
        // own frame values can lag a moment behind the actual new layout.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            self.setFrame(size: self.currentSize, animated: false)
        }
    }

    /// Updates the pill's live text (e.g. a running countdown) without
    /// changing its size/position — call `setExpanded` separately for that.
    func updateText(_ text: String?) {
        guard let hosting = window?.contentView as? NSHostingView<TriggerPillView> else { return }
        hosting.rootView = TriggerPillView(overrideText: text, isExpanded: text != nil)
    }

    /// Grows the pill downward while something needs to stay visible past
    /// the notch cutout (a running timer); shrinks it back to the small
    /// idle pill otherwise. The top edge never moves in either case.
    func setExpanded(_ expanded: Bool) {
        setFrame(size: expanded ? expandedSize : idleSize, animated: true)
    }

    private func setFrame(size: NSSize, animated: Bool) {
        currentSize = size
        // The screen whose frame origin is (0,0) is always the one
        // currently holding the menu bar/notch, regardless of which
        // display is plugged in as primary — recomputed fresh every call
        // rather than cached, since that's exactly what goes stale when
        // a monitor is connected/disconnected.
        guard let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main,
              let window else { return }
        let screenFrame = screen.frame
        let x = screenFrame.midX - size.width / 2
        let y = screenFrame.maxY - size.height
        let newFrame = NSRect(x: x, y: y, width: size.width, height: size.height)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                window.animator().setFrame(newFrame, display: true)
            }
        } else {
            window.setFrame(newFrame, display: true)
        }
    }
}

/// SwiftUI content of the pill itself. Two distinct looks, matching the
/// reference:
/// - Idle: a small rounded-all-corners black pill with an icon + label —
///   our own trigger affordance (the reference just uses a real menu bar
///   icon here, which isn't an option given how crowded the target
///   machine's menu bar is — see AppDelegate/README for why).
/// - Running: widened, bottom-corners-only rounded (flush square top,
///   matching the physical notch cutout exactly), showing *only* the
///   countdown — no icon, no label — mimicking the reference's
///   "extended hardware notch" illusion.
struct TriggerPillView: View {
    var overrideText: String? = nil
    var isExpanded: Bool = false

    var body: some View {
        Group {
            if isExpanded, let overrideText {
                DotMatrixText(
                    text: overrideText,
                    dotSize: 1.6,
                    dotSpacing: 0.9,
                    charSpacing: 2.5,
                    onColor: .white.opacity(0.85),
                    offColor: .white.opacity(0.08)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 8)
                .background(BottomRoundedRect(radius: 16).fill(Color.black))
            } else {
                HStack(spacing: 5) {
                    AppLogo(size: 11)
                    Text("Notchingale")
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.black))
            }
        }
    }
}

/// NSHostingView subclass that reports plain hover in/out and right-clicks
/// via callbacks — deliberately AppKit-level (NSTrackingArea) rather than
/// relying on SwiftUI's `.onHover`/gestures inside a non-activating panel,
/// since that combination has been unreliable to reason about without a
/// way to test it directly on-device.
final class HoverableHostingView<Content: View>: NSHostingView<Content> {
    private let onHoverChanged: (Bool) -> Void
    private let onRightClick: (NSView) -> Void

    init(rootView: Content, onHoverChanged: @escaping (Bool) -> Void, onRightClick: @escaping (NSView) -> Void) {
        self.onHoverChanged = onHoverChanged
        self.onRightClick = onRightClick
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @available(*, unavailable)
    required init(rootView: Content) {
        fatalError("init(rootView:) is not supported — use init(rootView:onHoverChanged:onRightClick:)")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged(false)
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick(self)
    }
}
