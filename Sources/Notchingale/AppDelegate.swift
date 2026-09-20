import AppKit
import SwiftUI
import Combine

/// Appends a timestamped line to ~/Desktop/Notchingale-debug.log. Kept
/// from earlier troubleshooting — harmless to leave in, delete the calls
/// (and this function) once you're confident everything launches cleanly.
func debugLog(_ message: String) {
    let line = "\(Date()) — \(message)\n"
    let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Desktop/Notchingale-debug.log")
    if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8) ?? Data())
        try? handle.close()
    } else {
        try? line.write(to: url, atomically: true, encoding: .utf8)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var trigger: NotchTriggerWindowController!
    private var dashboard: DashboardWindowController!
    private var cancellables: Set<AnyCancellable> = []

    let store = AppStore()
    let uiState = AppUIState()
    let timer = FocusTimerModel()
    let calendarService = CalendarService()
    let settings = AppSettings()

    private var mainWindowController: MainWindowController?

    // Hover state for the pill and the dashboard content separately — the
    // dashboard stays open as long as either one is hovered, and closes a
    // short grace period after both become false (so moving the pointer
    // from the pill down into the dashboard doesn't flicker-close it).
    private var isPillHovered = false
    private var isDashboardHovered = false
    /// A count rather than a bool: there are now two independent popover
    /// sources (event details, per-task focus duration), and each is
    /// independent per-row @State — it's possible, if unlikely, for more
    /// than one to be open at once. A bool would get clobbered if one
    /// closes while another is still open (its "false" would incorrectly
    /// stomp the other's "true"); a count handles that correctly
    /// regardless of open/close order.
    private var openChildPopoverCount = 0
    private var isChildPopoverOpen: Bool { openChildPopoverCount > 0 }
    private var closeWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        debugLog("applicationDidFinishLaunching started")

        timer.onFinish = { [weak self] title, start, elapsed in
            self?.store.recordFocusSession(taskTitle: title, startedAt: start, durationSeconds: elapsed)
            NotificationManager.shared.notifyFocusSessionComplete(taskTitle: title)
        }

        calendarService.requestAccessAndRefresh()
        NotificationManager.shared.requestAuthorization()

        trigger = NotchTriggerWindowController(
            onHoverChanged: { [weak self] hovering in self?.pillHoverChanged(hovering) },
            onRightClick: { [weak self] view in self?.showQuitMenu(from: view) }
        )
        trigger.showWindow(nil)
        debugLog("notch trigger window shown")

        let contentView = ContentView(
            store: store, uiState: uiState, timer: timer, calendarService: calendarService, settings: settings,
            openFullWindow: { [weak self] in self?.openMainWindow() },
            onClose: { [weak self] in self?.closeDashboardManually() },
            onHoverChanged: { [weak self] hovering in self?.dashboardHoverChanged(hovering) },
            onChildPopoverChanged: { [weak self] isOpen in self?.childPopoverChanged(isOpen) }
        )
        dashboard = DashboardWindowController(
            rootView: contentView,
            size: NSSize(width: WorkspaceView.requiredWidth(for: settings), height: 380)
        )
        debugLog("dashboard panel created")

        // Live countdown on the pill itself while it's collapsed; the pill
        // also grows/reshapes (away from the notch cutout) while running.
        timer.$remainingSeconds
            .combineLatest(timer.$mode)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, mode in
                self?.updateTriggerText()
                self?.trigger.setExpanded(mode != .idle)
            }
            .store(in: &cancellables)

        // Resize the dashboard any time the enabled-cards set changes, so
        // toggling a card in Settings never leaves it too narrow (or
        // unnecessarily wide) for what's actually showing.
        settings.$showTasks.combineLatest(settings.$showFocus, settings.$showNotes, settings.$showEvents)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _, _ in
                guard let self, let anchor = self.trigger.window?.frame else { return }
                let size = NSSize(width: WorkspaceView.requiredWidth(for: self.settings), height: 380)
                self.dashboard.updateSize(size, anchorBelow: anchor)
            }
            .store(in: &cancellables)

        debugLog("applicationDidFinishLaunching finished successfully")
    }

    private func updateTriggerText() {
        if timer.mode != .idle && !dashboard.isVisible {
            trigger.updateText(timer.formattedRemaining)
        } else {
            trigger.updateText(nil)
        }
    }

    // MARK: Hover-driven open/close

    private func pillHoverChanged(_ hovering: Bool) {
        isPillHovered = hovering
        hovering ? openDashboardForHover() : scheduleCloseIfUnhovered()
    }

    private func dashboardHoverChanged(_ hovering: Bool) {
        isDashboardHovered = hovering
        hovering ? cancelScheduledClose() : scheduleCloseIfUnhovered()
    }

    /// Called when any event-detail or focus-duration popover opens/
    /// closes — both are genuinely separate OS windows, same underlying
    /// issue. While at least one is open, cancel any pending close
    /// outright. Once the count returns to zero, re-check normally in
    /// case the cursor already isn't over the pill or dashboard anymore.
    private func childPopoverChanged(_ isOpen: Bool) {
        openChildPopoverCount = max(0, openChildPopoverCount + (isOpen ? 1 : -1))
        if isChildPopoverOpen {
            cancelScheduledClose()
        } else {
            scheduleCloseIfUnhovered()
        }
    }

    private func openDashboardForHover() {
        cancelScheduledClose()
        guard let anchorFrame = trigger.window?.frame else { return }
        if !dashboard.isVisible {
            calendarService.refresh()
            let size = NSSize(width: WorkspaceView.requiredWidth(for: settings), height: 380)
            dashboard.show(anchorBelow: anchorFrame, size: size)
            updateTriggerText()
        }
    }

    private func scheduleCloseIfUnhovered() {
        cancelScheduledClose()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if !self.isPillHovered && !self.isDashboardHovered && !self.isChildPopoverOpen {
                self.closeDashboard()
            }
        }
        closeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func cancelScheduledClose() {
        closeWorkItem?.cancel()
        closeWorkItem = nil
    }

    private func closeDashboard() {
        dashboard.hide()
        updateTriggerText()
    }

    /// The explicit "X" close button — hides immediately and forgets
    /// whatever the current hover state was, so it doesn't just pop back
    /// open on the next hover-state check.
    private func closeDashboardManually() {
        cancelScheduledClose()
        isDashboardHovered = false
        closeDashboard()
    }

    // MARK: Right-click menu

    private func showQuitMenu(from view: NSView) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open app", action: #selector(openMainWindowFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Notchingale", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        for item in menu.items { item.target = self }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height), in: view)
    }

    @objc private func openMainWindowFromMenu() {
        openMainWindow()
    }

    private func openMainWindow() {
        closeDashboardManually()
        if mainWindowController == nil {
            mainWindowController = MainWindowController(store: store, uiState: uiState, timer: timer, calendarService: calendarService, settings: settings)
        }
        mainWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
