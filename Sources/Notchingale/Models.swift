import Foundation
import Combine

// MARK: - Reminder options (context menu: "Remind Me")

enum ReminderOption: String, CaseIterable, Identifiable {
    case in30Minutes = "In 30 Minutes"
    case in1Hour = "In 1 Hour"
    case thisEvening = "This Evening"
    case tomorrowMorning = "Tomorrow Morning"

    var id: String { rawValue }

    /// Resolves the option to a concrete date, relative to `now`.
    func resolvedDate(from now: Date = Date()) -> Date {
        let cal = Calendar.current
        switch self {
        case .in30Minutes:
            return cal.date(byAdding: .minute, value: 30, to: now) ?? now
        case .in1Hour:
            return cal.date(byAdding: .hour, value: 1, to: now) ?? now
        case .thisEvening:
            var comps = cal.dateComponents([.year, .month, .day], from: now)
            comps.hour = 19
            let evening = cal.date(from: comps) ?? now
            return evening > now ? evening : (cal.date(byAdding: .hour, value: 1, to: now) ?? now)
        case .tomorrowMorning:
            let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
            var comps = cal.dateComponents([.year, .month, .day], from: tomorrow)
            comps.hour = 9
            return cal.date(from: comps) ?? tomorrow
        }
    }
}

// MARK: - Focus duration presets (context menu: "Focus" / "Set Time Limit")

enum FocusPreset: Int, CaseIterable, Identifiable {
    case fifteen = 15
    case twentyFive = 25
    case fortyFive = 45
    case sixty = 60

    var id: Int { rawValue }
    var label: String { "\(rawValue)m" }
}

// MARK: - Task

struct TaskItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    var order: Int
    var createdAt: Date
    var completedAt: Date?
    var dueDay: Date            // normalized to midnight; which day this task belongs to
    var reminderAt: Date?
    var plannedMinutes: Int?    // set via "Set Time Limit…" or reused by "Focus"

    init(title: String, order: Int, dueDay: Date = Calendar.current.startOfDay(for: Date())) {
        self.id = UUID()
        self.title = title
        self.isDone = false
        self.order = order
        self.createdAt = Date()
        self.completedAt = nil
        self.dueDay = dueDay
        self.reminderAt = nil
        self.plannedMinutes = nil
    }
}

// MARK: - Focus session history (for Insights)

struct FocusSession: Identifiable, Codable {
    let id: UUID
    var taskTitle: String
    var startedAt: Date
    var durationSeconds: Int

    init(taskTitle: String, startedAt: Date, durationSeconds: Int) {
        self.id = UUID()
        self.taskTitle = taskTitle
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
    }
}

// MARK: - Persisted snapshot

private struct Snapshot: Codable {
    var tasks: [TaskItem]
    var notepad: String
    var focusHistory: [FocusSession]
}

/// Single source of truth for the app. Persists to
/// ~/Library/Application Support/Notchingale/store.json
final class AppStore: ObservableObject {

    @Published var tasks: [TaskItem] = []
    @Published var notepad: String = ""
    @Published var focusHistory: [FocusSession] = []

    private var saveCancellable: AnyCancellable?
    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Notchingale", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("store.json")

        load()

        saveCancellable = Publishers.CombineLatest3($tasks, $notepad, $focusHistory)
            .debounce(for: .seconds(0.4), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.save() }

        NotificationCenter.default.addObserver(
            forName: .notchingaleResetData, object: nil, queue: .main
        ) { [weak self] _ in
            self?.tasks = []
            self?.notepad = ""
            self?.focusHistory = []
        }
    }

    // MARK: Derived

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    /// Today's card only shows tasks due today-or-earlier that aren't done,
    /// plus anything completed today (so the counter/checkmarks make sense).
    var todaysTasks: [TaskItem] {
        tasks
            .filter { $0.dueDay <= today && (!$0.isDone || Calendar.current.isDateInToday($0.completedAt ?? .distantPast)) }
            .sorted { $0.order < $1.order }
    }

    var todaysCompletedCount: Int { todaysTasks.filter { $0.isDone }.count }

    var remindersDueSoon: [TaskItem] {
        tasks.filter { $0.reminderAt != nil && !$0.isDone }.sorted { ($0.reminderAt ?? .distantFuture) < ($1.reminderAt ?? .distantFuture) }
    }

    /// All tasks (done or not) whose `dueDay` matches the given day —
    /// this is how you look back at a previous day's list, since
    /// `todaysTasks` intentionally hides old completed items.
    func tasks(on day: Date) -> [TaskItem] {
        let cal = Calendar.current
        return tasks
            .filter { cal.isDate($0.dueDay, inSameDayAs: day) }
            .sorted { $0.order < $1.order }
    }

    /// The last `count` days (including today), most recent first — for a
    /// day picker in the History / Insights UI.
    func recentDays(count: Int = 14) -> [Date] {
        let cal = Calendar.current
        let start = today
        return (0..<count).map { cal.date(byAdding: .day, value: -$0, to: start)! }
    }

    // MARK: Mutations

    func addTask(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (tasks.map(\.order).max() ?? -1) + 1
        tasks.append(TaskItem(title: trimmed, order: nextOrder, dueDay: today))
    }

    func toggleDone(_ task: TaskItem) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].isDone.toggle()
        tasks[idx].completedAt = tasks[idx].isDone ? Date() : nil
        if tasks[idx].isDone {
            NotificationManager.shared.cancelReminder(taskID: task.id)
        }
    }

    func rename(_ task: TaskItem, to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].title = trimmed
    }

    func setTimeLimit(_ task: TaskItem, minutes: Int) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].plannedMinutes = minutes
    }

    func setReminder(_ task: TaskItem, at date: Date) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].reminderAt = date
        NotificationManager.shared.scheduleReminder(taskID: task.id, title: task.title, at: date)
    }

    func clearReminder(_ task: TaskItem) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].reminderAt = nil
        NotificationManager.shared.cancelReminder(taskID: task.id)
    }

    func moveToTomorrow(_ task: TaskItem) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].dueDay = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
    }

    func duplicate(_ task: TaskItem) {
        let nextOrder = (tasks.map(\.order).max() ?? -1) + 1
        var copy = TaskItem(title: task.title, order: nextOrder, dueDay: task.dueDay)
        copy.plannedMinutes = task.plannedMinutes
        tasks.append(copy)
    }

    func deleteTask(_ task: TaskItem) {
        NotificationManager.shared.cancelReminder(taskID: task.id)
        tasks.removeAll { $0.id == task.id }
    }

    /// Reorders `todaysTasks` per a SwiftUI `.onMove` call, then re-numbers
    /// the `order` field of every task in the list to match.
    func moveTodaysTasks(fromOffsets source: IndexSet, toOffset destination: Int) {
        var visible = todaysTasks
        visible.move(fromOffsets: source, toOffset: destination)
        for (index, task) in visible.enumerated() {
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[idx].order = index
            }
        }
    }

    // MARK: Focus history

    func recordFocusSession(taskTitle: String, startedAt: Date, durationSeconds: Int) {
        guard durationSeconds > 0 else { return }
        focusHistory.insert(FocusSession(taskTitle: taskTitle, startedAt: startedAt, durationSeconds: durationSeconds), at: 0)
    }

    var totalFocusSecondsToday: Int {
        let cal = Calendar.current
        return focusHistory.filter { cal.isDateInToday($0.startedAt) }.reduce(0) { $0 + $1.durationSeconds }
    }

    /// Daily focus minutes for the last 7 days (oldest first), for the Insights chart.
    func focusMinutesByDay(daysBack: Int = 7) -> [(day: Date, minutes: Int)] {
        let cal = Calendar.current
        let days = (0..<daysBack).map { cal.date(byAdding: .day, value: -$0, to: today)! }.reversed()
        return days.map { day in
            let minutes = focusHistory
                .filter { cal.isDate($0.startedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.durationSeconds } / 60
            return (day, minutes)
        }
    }

    // MARK: Insights (7-day dashboard)

    /// One day's worth of numbers for the Insights chart/summary: how many
    /// tasks were due that day, how many of those got completed, and how
    /// many minutes were spent focusing.
    struct DayStat: Identifiable {
        let day: Date
        let completedTasks: Int
        let plannedTasks: Int
        let focusMinutes: Int
        var id: Date { day }
    }

    /// The last `daysBack` days (oldest first) with completed/planned task
    /// counts and focus minutes for each — backs both cards in Insights.
    func dayStats(daysBack: Int = 7) -> [DayStat] {
        let cal = Calendar.current
        let days = (0..<daysBack).map { cal.date(byAdding: .day, value: -$0, to: today)! }.reversed()
        return days.map { day in
            let dayTasks = tasks(on: day)
            let completed = dayTasks.filter { $0.isDone }.count
            let focusMin = focusHistory
                .filter { cal.isDate($0.startedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.durationSeconds } / 60
            return DayStat(day: day, completedTasks: completed, plannedTasks: dayTasks.count, focusMinutes: focusMin)
        }
    }

    /// Consecutive days, counting back from today, with at least one
    /// completed task or logged focus session.
    var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var day = today
        while true {
            let hadActivity = tasks(on: day).contains { $0.isDone }
                || focusHistory.contains { cal.isDate($0.startedAt, inSameDayAs: day) }
            guard hadActivity else { break }
            streak += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        tasks = snapshot.tasks
        notepad = snapshot.notepad
        focusHistory = snapshot.focusHistory
    }

    private func save() {
        let snapshot = Snapshot(tasks: tasks, notepad: notepad, focusHistory: focusHistory)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Focus timer engine

final class FocusTimerModel: ObservableObject {
    enum Mode: Equatable { case idle, running, paused }

    @Published var mode: Mode = .idle
    @Published var remainingSeconds: Int = 25 * 60
    @Published var totalSeconds: Int = 25 * 60
    @Published var linkedTaskTitle: String = ""
    @Published var linkedTaskID: UUID?

    private var timer: Timer?
    private var sessionStart: Date?
    /// Fires each time the timer finishes naturally (hits zero), so the
    /// menu bar / task badges can react without polling.
    var onFinish: ((_ taskTitle: String, _ startedAt: Date, _ elapsed: Int) -> Void)?

    func start(minutes: Int, taskTitle: String, taskID: UUID? = nil) {
        totalSeconds = minutes * 60
        remainingSeconds = totalSeconds
        linkedTaskTitle = taskTitle
        linkedTaskID = taskID
        sessionStart = Date()
        mode = .running
        tick()
    }

    func pause() {
        guard mode == .running else { return }
        mode = .paused
        timer?.invalidate()
    }

    func resume() {
        guard mode == .paused else { return }
        mode = .running
        tick()
    }

    func setTime(minutes: Int) {
        guard mode == .idle else { return }
        totalSeconds = minutes * 60
        remainingSeconds = totalSeconds
    }

    /// "Checkmark" button: end the session early but still log it as complete.
    @discardableResult
    func complete() -> (taskTitle: String, startedAt: Date, elapsed: Int)? {
        stop()
    }

    @discardableResult
    func stop() -> (taskTitle: String, startedAt: Date, elapsed: Int)? {
        timer?.invalidate()
        timer = nil
        guard let start = sessionStart, mode != .idle else {
            mode = .idle
            return nil
        }
        let elapsed = totalSeconds - remainingSeconds
        mode = .idle
        linkedTaskID = nil
        remainingSeconds = totalSeconds
        sessionStart = nil
        return (linkedTaskTitle, start, elapsed)
    }

    private func tick() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.mode == .running else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
            } else {
                self.timer?.invalidate()
                let title = self.linkedTaskTitle
                let start = self.sessionStart ?? Date()
                let elapsed = self.totalSeconds
                self.mode = .idle
                self.linkedTaskID = nil
                self.sessionStart = nil
                self.onFinish?(title, start, elapsed)
            }
        }
    }

    var progress: Double {
        totalSeconds == 0 ? 0 : Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    var formattedRemaining: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

/// Drives which top-level tab is showing.
final class AppUIState: ObservableObject {
    enum Tab: String, CaseIterable, Identifiable {
        case workspace = "Workspace"
        case insights = "Insights"
        case settings = "Settings"
        var id: String { rawValue }
    }

    @Published var selectedTab: Tab = .workspace
}
