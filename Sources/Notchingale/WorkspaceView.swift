import SwiftUI
import AppKit

struct WorkspaceView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var timer: FocusTimerModel
    @ObservedObject var calendarService: CalendarService
    @ObservedObject var settings: AppSettings
    var onChildPopoverChanged: ((Bool) -> Void)? = nil

    static let cardSpacing: CGFloat = 12
    static let outerPadding: CGFloat = 14 // each side
    static let handleWidth: CGFloat = 10

    /// Exact content width required to show the currently-enabled cards
    /// (at their current, possibly user-resized widths) with no clipping,
    /// plus a small safety margin. Since resizing only ever transfers
    /// width between two neighbors (see `ResizeHandle`), the sum of all
    /// four widths is stable regardless of how the user has dragged them.
    static func requiredWidth(for settings: AppSettings) -> CGFloat {
        var widths: [CGFloat] = []
        if settings.showTasks { widths.append(settings.taskWidth) }
        if settings.showFocus { widths.append(settings.focusWidth) }
        if settings.showNotes { widths.append(settings.notesWidth) }
        if settings.showEvents { widths.append(settings.eventsWidth) }

        guard !widths.isEmpty else { return 320 } // "nothing enabled" placeholder width

        let cardsTotal = widths.reduce(0, +)
        let gaps = cardSpacing * CGFloat(widths.count - 1)
        let handles = handleWidth * CGFloat(max(widths.count - 1, 0))
        let padding = outerPadding * 2
        return cardsTotal + gaps + handles + padding + 8 // small safety margin
    }

    private enum CardKind: CaseIterable {
        case tasks, focus, notes, events
    }

    private func isEnabled(_ kind: CardKind) -> Bool {
        switch kind {
        case .tasks: return settings.showTasks
        case .focus: return settings.showFocus
        case .notes: return settings.showNotes
        case .events: return settings.showEvents
        }
    }

    private func width(_ kind: CardKind) -> CGFloat {
        switch kind {
        case .tasks: return settings.taskWidth
        case .focus: return settings.focusWidth
        case .notes: return settings.notesWidth
        case .events: return settings.eventsWidth
        }
    }

    private func widthKeyPath(_ kind: CardKind) -> ReferenceWritableKeyPath<AppSettings, CGFloat> {
        switch kind {
        case .tasks: return \AppSettings.taskWidth
        case .focus: return \AppSettings.focusWidth
        case .notes: return \AppSettings.notesWidth
        case .events: return \AppSettings.eventsWidth
        }
    }

    @ViewBuilder
    private func cardView(_ kind: CardKind) -> some View {
        switch kind {
        case .tasks: TaskCardView(store: store, timer: timer, onChildPopoverChanged: onChildPopoverChanged)
        case .focus: TimerCardView(store: store, timer: timer)
        case .notes: NotepadCardView(store: store)
        case .events: EventsCardView(store: store, calendarService: calendarService, onChildPopoverChanged: onChildPopoverChanged)
        }
    }

    private var enabledCards: [CardKind] {
        CardKind.allCases.filter(isEnabled)
    }

    var body: some View {
        if settings.enabledCount == 0 {
            emptyState
        } else {
            HStack(alignment: .top, spacing: Self.cardSpacing) {
                let cards = enabledCards
                ForEach(Array(cards.enumerated()), id: \.offset) { index, kind in
                    cardView(kind)
                        .frame(width: width(kind))

                    if index < cards.count - 1 {
                        ResizeHandle(
                            settings: settings,
                            leftWidth: widthKeyPath(kind),
                            rightWidth: widthKeyPath(cards[index + 1])
                        )
                    }
                }
            }
            .padding(Self.outerPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No cards enabled")
                .font(.system(size: 13, weight: .semibold))
            Text("Turn on Tasks, Focus, Notepad, or Events in Settings.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A thin drag handle between two adjacent cards. Dragging transfers
/// width from one to the other (total stays constant), and the cursor
/// switches to a resize arrow on hover so it reads as draggable.
private struct ResizeHandle: View {
    @ObservedObject var settings: AppSettings
    let leftWidth: ReferenceWritableKeyPath<AppSettings, CGFloat>
    let rightWidth: ReferenceWritableKeyPath<AppSettings, CGFloat>

    @State private var dragStartLeft: CGFloat?
    @State private var dragStartRight: CGFloat?

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.001)) // invisible but hit-testable
            .frame(width: WorkspaceView.handleWidth)
            .contentShape(Rectangle())
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1)
            )
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    NSCursor.resizeLeftRight.set()
                case .ended:
                    NSCursor.arrow.set()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if dragStartLeft == nil {
                            dragStartLeft = settings[keyPath: leftWidth]
                            dragStartRight = settings[keyPath: rightWidth]
                        }
                        guard let startLeft = dragStartLeft, let startRight = dragStartRight else { return }
                        // Reset to the drag-start widths each time, then
                        // apply the *total* translation — avoids drift
                        // from repeatedly applying small deltas.
                        settings[keyPath: leftWidth] = startLeft
                        settings[keyPath: rightWidth] = startRight
                        settings.resizeAdjacent(leftWidth: leftWidth, rightWidth: rightWidth, delta: value.translation.width)
                    }
                    .onEnded { _ in
                        dragStartLeft = nil
                        dragStartRight = nil
                    }
            )
    }
}

/// Shared chrome for every pastel widget: colored rounded rect, title row,
/// consistent padding. Content differs per-card.
struct CardContainer<Content: View>: View {
    let title: String
    let tint: Color
    let titleIcon: String?
    let trailing: AnyView?
    @ViewBuilder var content: () -> Content

    init(title: String, tint: Color, titleIcon: String? = nil, trailing: AnyView? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.tint = tint
        self.titleIcon = titleIcon
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if let titleIcon {
                    Image(systemName: titleIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.cardTextPrimary)
                }
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.cardTextPrimary)
                }
                Spacer()
                if let trailing {
                    trailing
                }
            }
            content()
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(tint)
        .overlay(NoiseTexture())
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}
