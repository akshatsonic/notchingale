import Foundation
import Combine

/// Which of the 4 workspace cards the user wants visible. Persisted to
/// UserDefaults (separate from AppStore's JSON — this is presentation
/// preference, not app data).
final class AppSettings: ObservableObject {
    @Published var showTasks: Bool { didSet { defaults.set(showTasks, forKey: Key.tasks) } }
    @Published var showFocus: Bool { didSet { defaults.set(showFocus, forKey: Key.focus) } }
    @Published var showNotes: Bool { didSet { defaults.set(showNotes, forKey: Key.notes) } }
    @Published var showEvents: Bool { didSet { defaults.set(showEvents, forKey: Key.events) } }

    // Per-card widths, user-adjustable via the drag handles between cards.
    // Dragging a handle only ever transfers width between the two
    // immediate neighbors (see `WorkspaceView`'s ResizeHandle), so the sum
    // of these four never changes — which matters because the dashboard
    // panel's total width is computed from that sum (see
    // `WorkspaceView.requiredWidth`) and must never silently drift out of
    // sync with what's actually being laid out.
    @Published var taskWidth: CGFloat { didSet { defaults.set(Double(taskWidth), forKey: Key.taskWidth) } }
    @Published var focusWidth: CGFloat { didSet { defaults.set(Double(focusWidth), forKey: Key.focusWidth) } }
    @Published var notesWidth: CGFloat { didSet { defaults.set(Double(notesWidth), forKey: Key.notesWidth) } }
    @Published var eventsWidth: CGFloat { didSet { defaults.set(Double(eventsWidth), forKey: Key.eventsWidth) } }

    private let defaults = UserDefaults.standard
    private enum Key {
        static let tasks = "Notchingale.showTasks"
        static let focus = "Notchingale.showFocus"
        static let notes = "Notchingale.showNotes"
        static let events = "Notchingale.showEvents"
        static let taskWidth = "Notchingale.taskWidth"
        static let focusWidth = "Notchingale.focusWidth"
        static let notesWidth = "Notchingale.notesWidth"
        static let eventsWidth = "Notchingale.eventsWidth"
    }

    init() {
        let d = UserDefaults.standard
        showTasks = (d.object(forKey: Key.tasks) as? Bool) ?? true
        showFocus = (d.object(forKey: Key.focus) as? Bool) ?? true
        showNotes = (d.object(forKey: Key.notes) as? Bool) ?? true
        showEvents = (d.object(forKey: Key.events) as? Bool) ?? true

        taskWidth = (d.object(forKey: Key.taskWidth) as? Double).map { CGFloat($0) } ?? 260
        focusWidth = (d.object(forKey: Key.focusWidth) as? Double).map { CGFloat($0) } ?? 190
        notesWidth = (d.object(forKey: Key.notesWidth) as? Double).map { CGFloat($0) } ?? 190
        eventsWidth = (d.object(forKey: Key.eventsWidth) as? Double).map { CGFloat($0) } ?? 240
    }

    var enabledCount: Int {
        [showTasks, showFocus, showNotes, showEvents].filter { $0 }.count
    }

    static let minCardWidth: CGFloat = 140
    static let maxCardWidth: CGFloat = 420

    /// Moves `delta` points of width from the left card to the right card
    /// (or the reverse, for a negative delta), clamped so neither card
    /// goes below the minimum or above the maximum. Used by the drag
    /// handle between two adjacent enabled cards — total width is always
    /// conserved since one side's gain is exactly the other's loss.
    func resizeAdjacent(leftWidth: ReferenceWritableKeyPath<AppSettings, CGFloat>, rightWidth: ReferenceWritableKeyPath<AppSettings, CGFloat>, delta: CGFloat) {
        let left = self[keyPath: leftWidth]
        let right = self[keyPath: rightWidth]
        var newLeft = left + delta
        var newRight = right - delta
        if newLeft < Self.minCardWidth {
            let shortfall = Self.minCardWidth - newLeft
            newLeft = Self.minCardWidth
            newRight -= shortfall
        }
        if newRight < Self.minCardWidth {
            let shortfall = Self.minCardWidth - newRight
            newRight = Self.minCardWidth
            newLeft -= shortfall
        }
        newLeft = min(max(newLeft, Self.minCardWidth), Self.maxCardWidth)
        newRight = min(max(newRight, Self.minCardWidth), Self.maxCardWidth)
        self[keyPath: leftWidth] = newLeft
        self[keyPath: rightWidth] = newRight
    }
}
