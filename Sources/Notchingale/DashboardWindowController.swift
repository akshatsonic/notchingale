import AppKit
import QuartzCore
import SwiftUI

/// NSPanel subclass that can become key despite being borderless and
/// non-activating — needed so TextFields (task input, notepad) actually
/// receive keyboard focus. Without this override, a borderless panel's
/// default `canBecomeKey` is false and typing into any control silently
/// does nothing.
final class KeyableBorderlessPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// The main dashboard "window housing" — deliberately not an NSPopover.
/// NSPopover always draws its own arrow/pointer chrome pointing at the
/// anchor view, and there's no public API to suppress that; the reference
/// design sits flush under the trigger with no arrow at all, which means
/// it has to be a plain custom panel instead.
final class DashboardWindowController: NSWindowController {

    init(rootView: ContentView, size: NSSize) {
        let panel = KeyableBorderlessPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.contentView = NSHostingView(rootView: rootView)

        super.init(window: panel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    /// Resizes the panel (e.g. when the enabled-cards set changes) and
    /// keeps it flush against the given anchor rect's bottom edge.
    func updateSize(_ size: NSSize, anchorBelow anchorFrame: NSRect) {
        guard let window else { return }
        let x = anchorFrame.midX - size.width / 2
        let y = anchorFrame.minY - size.height
        window.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: window.isVisible)
    }

    /// Shows the panel flush against the bottom edge of `anchorFrame`
    /// (the trigger pill's current on-screen frame), centered under it —
    /// animated as an "opening" reveal.
    ///
    /// This does NOT animate the window's actual frame. That was the
    /// previous approach, and it's exactly what caused the visible
    /// stutter: animating an NSWindow's frame forces the SwiftUI content
    /// inside to re-layout at every intermediate size along the way, and
    /// this dashboard's content (four cards, a List, texture overlays)
    /// is expensive enough to re-layout that the animation visibly
    /// dropped frames.
    ///
    /// Instead: the window jumps straight to its full final size (so
    /// SwiftUI lays out the content exactly once, not continuously),
    /// then a Core Animation mask layer grows from the pill's height up
    /// to the full height. Masking an already-laid-out layer is cheap,
    /// GPU-side work — no SwiftUI re-layout involved at all — which is
    /// what should actually make this smooth.
    func show(anchorBelow anchorFrame: NSRect, size: NSSize) {
        guard let window, let contentView = window.contentView else { return }
        let targetFrame = NSRect(
            x: anchorFrame.midX - size.width / 2,
            y: anchorFrame.minY - size.height,
            width: size.width,
            height: size.height
        )
        let duration: CFTimeInterval = 0.26

        contentView.wantsLayer = true
        let maskLayer = CALayer()
        maskLayer.backgroundColor = NSColor.black.cgColor

        // Apply the starting state with no implicit animation of its
        // own: full-size window immediately, masked down to just the
        // pill's own height, fully transparent — then the actual
        // animation below only ever touches the mask's height and the
        // window's alpha, never the frame/layout again.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        window.setFrame(targetFrame, display: false)
        maskLayer.frame = CGRect(x: 0, y: 0, width: size.width, height: anchorFrame.height)
        contentView.layer?.mask = maskLayer
        CATransaction.commit()
        window.alphaValue = 0

        // makeKeyAndOrderFront (not just orderFront) so text fields inside
        // can receive keyboard input immediately.
        window.makeKeyAndOrderFront(nil)

        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        CATransaction.setCompletionBlock { [weak contentView] in
            // Remove the mask once fully revealed — cheaper to leave the
            // layer unmasked afterward than keep an always-full-size
            // mask sitting there for no reason.
            contentView?.layer?.mask = nil
        }
        maskLayer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        CATransaction.commit()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let window else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            window.alphaValue = 1 // reset so the next show() starts fully opaque
        })
    }
}
