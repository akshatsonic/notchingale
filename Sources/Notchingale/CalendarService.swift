import Foundation
import EventKit
import Combine

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let calendarTitle: String?

    var isHappeningNow: Bool {
        let now = Date()
        return startDate <= now && now <= endDate
    }
}

/// Thin wrapper around EventKit. Access must be granted by the user via the
/// system permission prompt (backed by the Info.plist usage-description keys) —
/// this class degrades gracefully to an empty, "not connected" state if denied.
final class CalendarService: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var todaysEvents: [CalendarEvent] = []

    private let store = EKEventStore()

    func requestAccessAndRefresh() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.isConnected = granted
                    if granted { self?.refresh() }
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.isConnected = granted
                    if granted { self?.refresh() }
                }
            }
        }
    }

    func refresh() {
        let status = EKEventStore.authorizationStatus(for: .event)
        let authorized: Bool
        if #available(macOS 14.0, *) {
            authorized = status == .fullAccess
        } else {
            authorized = status == .authorized
        }
        guard authorized else {
            isConnected = false
            todaysEvents = []
            return
        }
        isConnected = true

        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map {
                CalendarEvent(
                    id: $0.eventIdentifier ?? UUID().uuidString,
                    title: $0.title ?? "Untitled event",
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    isAllDay: $0.isAllDay,
                    location: $0.location,
                    notes: $0.notes,
                    calendarTitle: $0.calendar?.title
                )
            }
        todaysEvents = events
    }
}
