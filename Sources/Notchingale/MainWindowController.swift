import AppKit
import SwiftUI

final class MainWindowController: NSWindowController {

    init(store: AppStore, uiState: AppUIState, timer: FocusTimerModel, calendarService: CalendarService, settings: AppSettings) {
        let width = max(WorkspaceView.requiredWidth(for: settings), 480)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Notchingale"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: ContentView(store: store, uiState: uiState, timer: timer, calendarService: calendarService, settings: settings, openFullWindow: nil)
        )
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
