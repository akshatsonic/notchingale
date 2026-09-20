import SwiftUI

struct EventsCardView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var calendarService: CalendarService
    /// Bubbles up to AppDelegate so it can suppress the dashboard's
    /// hover-driven auto-close while an event detail popover is open —
    /// that popover is a genuinely separate OS window, so the moment the
    /// cursor moves into it, the dashboard's own hover tracking sees the
    /// cursor "leave" and would otherwise start closing everything.
    var onChildPopoverChanged: ((Bool) -> Void)? = nil

    var body: some View {
        CardContainer(
            title: "Events",
            tint: Theme.eventsCard,
            titleIcon: "calendar",
            trailing: AnyView(
                Menu {
                    Button("Refresh") { calendarService.refresh() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.cardTextSecondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            )
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("TODAY")
                        .font(.system(size: 9.5, weight: .semibold))
                    Spacer()
                    Text(todayLabel)
                        .font(.system(size: 9.5, weight: .semibold))
                }
                .foregroundStyle(Theme.cardTextSecondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(store.remindersDueSoon) { task in
                            HStack(spacing: 6) {
                                Image(systemName: "bell.fill").font(.system(size: 10))
                                Text(task.title)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                Spacer()
                                if let date = task.reminderAt {
                                    Text(date, style: .time)
                                        .font(.system(size: 10.5))
                                }
                            }
                            .foregroundStyle(Theme.cardTextPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        if calendarService.todaysEvents.isEmpty {
                            Text(calendarService.isConnected ? "No events today." : "Calendar access not granted.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(Theme.cardTextSecondary)
                        } else {
                            ForEach(calendarService.todaysEvents) { event in
                                EventRow(event: event, onChildPopoverChanged: onChildPopoverChanged)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                        Text(calendarService.isConnected ? "Connected" : "Not connected")
                    }
                    Spacer()
                    Button {
                        calendarService.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.cardTextSecondary)
            }
        }
        .onAppear { calendarService.refresh() }
    }

    private var todayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d"
        return formatter.string(from: Date())
    }
}

private struct EventRow: View {
    let event: CalendarEvent
    var onChildPopoverChanged: ((Bool) -> Void)? = nil
    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(.system(size: 12))
                        .lineLimit(1)
                    Text(timeRange)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.cardTextSecondary)
                }
                Spacer()
                if event.isHappeningNow {
                    Text("Happening now")
                        .font(.system(size: 9.5, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.35))
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(Theme.cardTextPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDetail, arrowEdge: .leading) {
            EventDetailPopover(event: event)
        }
        .onChange(of: showDetail) { isShowing in
            onChildPopoverChanged?(isShowing)
        }
    }

    private var timeRange: String {
        if event.isAllDay { return "All day" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }
}
