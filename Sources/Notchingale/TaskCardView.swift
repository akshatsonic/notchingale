import SwiftUI

struct TaskCardView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var timer: FocusTimerModel
    /// Bubbles up to AppDelegate so it can suppress the dashboard's
    /// hover-driven auto-close while the Focus-duration popover (also a
    /// separate OS window, same as the event-detail one) is open.
    var onChildPopoverChanged: ((Bool) -> Void)? = nil
    @State private var newTaskTitle: String = ""

    private enum Inline: Equatable {
        case none
        case timeLimitPicker(TaskItem)
        case renaming(TaskItem)

        static func == (lhs: Inline, rhs: Inline) -> Bool {
            switch (lhs, rhs) {
            case (.none, .none): return true
            case let (.timeLimitPicker(a), .timeLimitPicker(b)): return a.id == b.id
            case let (.renaming(a), .renaming(b)): return a.id == b.id
            default: return false
            }
        }
    }

    @State private var inline: Inline = .none

    var body: some View {
        CardContainer(
            title: "Today's tasks",
            tint: Theme.taskCard,
            titleIcon: "list.bullet.clipboard",
            trailing: AnyView(
                Text("\(store.todaysCompletedCount) / \(store.todaysTasks.count)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.cardTextSecondary)
            )
        ) {
            switch inline {
            case .none:
                listBody
            case .timeLimitPicker(let task):
                DurationPickerInline(
                    task: task,
                    confirmLabel: "Set limit",
                    onPick: { minutes in
                        store.setTimeLimit(task, minutes: minutes)
                        inline = .none
                    },
                    onCancel: { inline = .none }
                )
            case .renaming(let task):
                RenameInline(
                    task: task,
                    onCommit: { newTitle in
                        store.rename(task, to: newTitle)
                        inline = .none
                    },
                    onCancel: { inline = .none }
                )
            }
        }
    }

    private var listBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("+")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.cardTextSecondary)
                TextField("", text: $newTaskTitle, prompt: Text("What needs doing?").foregroundColor(Theme.cardTextSecondary))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.cardTextPrimary)
                    .onSubmit(addTask)
                Image(systemName: "arrow.turn.down.left")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.cardTextSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.12))
            .clipShape(Capsule())

            DottedDivider()

            List {
                ForEach(store.todaysTasks) { task in
                    TaskRow(
                        task: task,
                        isActiveSession: timer.mode != .idle && timer.linkedTaskID == task.id,
                        elapsedMinutes: (timer.totalSeconds - timer.remainingSeconds) / 60,
                        onToggleDone: { store.toggleDone(task) },
                        onQuickStart: { timer.start(minutes: task.plannedMinutes ?? 25, taskTitle: task.title, taskID: task.id) },
                        onStartFocus: { minutes in
                            store.setTimeLimit(task, minutes: minutes)
                            timer.start(minutes: minutes, taskTitle: task.title, taskID: task.id)
                        },
                        onSaveFocusDuration: { minutes in store.setTimeLimit(task, minutes: minutes) },
                        onRename: { inline = .renaming(task) },
                        onSetTimeLimit: { inline = .timeLimitPicker(task) },
                        onRemind: { option in store.setReminder(task, at: option.resolvedDate()) },
                        onClearReminder: { store.clearReminder(task) },
                        onMoveToTomorrow: { store.moveToTomorrow(task) },
                        onDuplicate: { store.duplicate(task) },
                        onDelete: { store.deleteTask(task) },
                        onChildPopoverChanged: onChildPopoverChanged
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                }
                .onMove { source, destination in
                    store.moveTodaysTasks(fromOffsets: source, toOffset: destination)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(maxHeight: .infinity)

            DottedDivider()

            HStack {
                Text("Drag to reorder")
                Spacer()
                Text(todayLabel)
            }
            .font(.system(size: 10.5))
            .foregroundStyle(Theme.cardTextSecondary)
        }
    }

    private var todayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM"
        return formatter.string(from: Date())
    }

    private func addTask() {
        store.addTask(newTaskTitle)
        newTaskTitle = ""
    }
}

private struct TaskRow: View {
    let task: TaskItem
    let isActiveSession: Bool
    let elapsedMinutes: Int
    let onToggleDone: () -> Void
    let onQuickStart: () -> Void
    let onStartFocus: (Int) -> Void
    let onSaveFocusDuration: (Int) -> Void
    let onRename: () -> Void
    let onSetTimeLimit: () -> Void
    let onRemind: (ReminderOption) -> Void
    let onClearReminder: () -> Void
    let onMoveToTomorrow: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    var onChildPopoverChanged: ((Bool) -> Void)? = nil

    @State private var showFocusPopover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Button(action: onToggleDone) {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(task.isDone ? Color.black.opacity(0.6) : Theme.cardTextSecondary)
                }
                .buttonStyle(.plain)

                Text(task.title)
                    .font(.system(size: 12.5))
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? Theme.cardTextSecondary : Theme.cardTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !isActiveSession {
                    Button(action: onQuickStart) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.cardTextSecondary)
                    }
                    .buttonStyle(.plain)
                }

                rowMenu
            }

            if isActiveSession {
                HStack(spacing: 8) {
                    Image(systemName: "stopwatch").font(.system(size: 9))
                    Text("\(elapsedMinutes)m").font(.system(size: 10.5))
                    if let reminderAt = task.reminderAt {
                        Image(systemName: "bell.fill").font(.system(size: 9))
                        Text(reminderAt, style: .time).font(.system(size: 10.5))
                    }
                    Spacer()
                    Image(systemName: "waveform").font(.system(size: 9))
                    Text("Active session").font(.system(size: 10.5, weight: .medium))
                }
                .foregroundStyle(Theme.cardTextSecondary)
                .padding(.leading, 24)
            } else if let reminderAt = task.reminderAt {
                HStack(spacing: 3) {
                    Image(systemName: "bell.fill").font(.system(size: 8))
                    Text(reminderAt, style: .time).font(.system(size: 9.5))
                }
                .foregroundStyle(Theme.cardTextSecondary)
                .padding(.leading, 24)
            }
        }
        .padding(.vertical, isActiveSession ? 6 : 4)
        .padding(.horizontal, 8)
        .background(isActiveSession ? Color.black.opacity(0.08) : Color.white.opacity(0.001))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .popover(isPresented: $showFocusPopover, arrowEdge: .top) {
            FocusDurationPopover(
                taskTitle: task.title,
                onSave: { minutes in
                    onSaveFocusDuration(minutes)
                    showFocusPopover = false
                },
                onStart: { minutes in
                    onStartFocus(minutes)
                    showFocusPopover = false
                },
                onCancel: { showFocusPopover = false }
            )
        }
        .onChange(of: showFocusPopover) { isShowing in
            onChildPopoverChanged?(isShowing)
        }
    }

    private var rowMenu: some View {
        Menu {
            Button("Focus…") { showFocusPopover = true }
            Button(task.isDone ? "Mark as Not Done" : "Mark as Done", action: onToggleDone)
            Button("Rename…", action: onRename)
            Button("Set Time Limit…", action: onSetTimeLimit)
            Menu("Remind Me") {
                ForEach(ReminderOption.allCases) { option in
                    Button(option.rawValue) { onRemind(option) }
                }
                if task.reminderAt != nil {
                    Divider()
                    Button("Clear Reminder", action: onClearReminder)
                }
            }
            Button("Move to Tomorrow", action: onMoveToTomorrow)
            Button("Duplicate", action: onDuplicate)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11))
                .foregroundStyle(Theme.cardTextSecondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

/// The "Focus duration" popup from the reference (image 3): a light bubble
/// with a segmented 15/25/45/60 picker, a custom-minutes stepper, a hint
/// line, and Cancel / Save / Start actions. Forces light appearance since
/// the reference always shows it light regardless of system dark mode —
/// note this only affects SwiftUI's own color resolution inside the
/// popover; whether AppKit's own popover chrome also stays light on every
/// macOS version isn't something verifiable without a real device.
private struct FocusDurationPopover: View {
    let taskTitle: String
    let onSave: (Int) -> Void
    let onStart: (Int) -> Void
    let onCancel: () -> Void

    @State private var selectedPreset: FocusPreset? = .twentyFive
    @State private var customMinutes: Int = 25

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Focus duration")
                    .font(.system(size: 13, weight: .semibold))
                Text(taskTitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 4) {
                ForEach(FocusPreset.allCases) { preset in
                    Button {
                        selectedPreset = preset
                        customMinutes = preset.rawValue
                    } label: {
                        Text(preset.label)
                            .font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(selectedPreset == preset ? Color.black : Color.black.opacity(0.06))
                            .foregroundStyle(selectedPreset == preset ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("Custom")
                    .font(.system(size: 12))
                Spacer()
                Text("\(customMinutes)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                Text("min")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Stepper("", value: $customMinutes, in: 1...180)
                    .labelsHidden()
                    .onChange(of: customMinutes) { _ in selectedPreset = nil }
            }

            Text("Your timer starts when you begin focusing.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)

            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                Spacer()
                Button("Save") { onSave(customMinutes) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                Button("Start") { onStart(customMinutes) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .frame(width: 260)
        .environment(\.colorScheme, .light)
    }
}

/// Inline "modal" that replaces the task list content in-place — used for
/// both "Focus…" (15/25/45/60/custom, then starts the timer) and
/// "Set Time Limit…" (same presets, but only stores the value).
private struct DurationPickerInline: View {
    let task: TaskItem
    let confirmLabel: String
    let onPick: (Int) -> Void
    let onCancel: () -> Void

    @State private var customMinutes: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Time limit")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.cardTextPrimary)
            Text(task.title)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.cardTextSecondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                ForEach(FocusPreset.allCases) { preset in
                    Button(preset.label) { onPick(preset.rawValue) }
                        .buttonStyle(PresetButtonStyle())
                }
            }

            HStack(spacing: 6) {
                TextField("", text: $customMinutes, prompt: Text("Custom min").foregroundColor(Theme.cardTextSecondary))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.cardTextPrimary)
                    .padding(6)
                    .background(Color.white.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Button(confirmLabel) {
                    if let value = Int(customMinutes), value > 0 { onPick(value) }
                }
                .buttonStyle(PresetButtonStyle())
            }

            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Theme.cardTextSecondary)
        }
    }
}

private struct RenameInline: View {
    let task: TaskItem
    let onCommit: (String) -> Void
    let onCancel: () -> Void
    @State private var title: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rename task")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.cardTextPrimary)
            TextField("", text: $title, prompt: Text("Task title").foregroundColor(Theme.cardTextSecondary))
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.cardTextPrimary)
                .padding(7)
                .background(Color.white.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
                .onAppear { title = task.title }
                .onSubmit { onCommit(title) }
            HStack {
                Button("Save") { onCommit(title) }.buttonStyle(PresetButtonStyle())
                Button("Cancel", action: onCancel).buttonStyle(.plain).font(.system(size: 11))
            }
        }
    }
}

private struct PresetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(configuration.isPressed ? 0.5 : 0.35))
            .clipShape(Capsule())
            .foregroundStyle(Theme.cardTextPrimary)
    }
}
