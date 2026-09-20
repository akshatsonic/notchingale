import SwiftUI
import Foundation

/// A light-appearance popup showing an event's full details — title, time,
/// location, and notes — matching how clicking an event in Apple Calendar
/// opens a detail bubble. Any URLs found in the location or notes (video
/// call links, dial-in numbers, etc.) are rendered as real tappable links
/// rather than plain text.
struct EventDetailPopover: View {
    let event: CalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(event.title)
                .font(.system(size: 14, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)

            if let calendarTitle = event.calendarTitle {
                HStack(spacing: 5) {
                    Circle().fill(Color.accentColor).frame(width: 7, height: 7)
                    Text(calendarTitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 6) {
                Image(systemName: "clock").font(.system(size: 11)).foregroundStyle(.secondary)
                Text(timeRangeText)
                    .font(.system(size: 12))
            }

            if let location = event.location, !location.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "mappin.and.ellipse").font(.system(size: 11)).foregroundStyle(.secondary)
                    LinkifiedText(location)
                        .font(.system(size: 12))
                }
            }

            if let notes = event.notes, !notes.isEmpty {
                Divider()
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "text.alignleft").font(.system(size: 11)).foregroundStyle(.secondary)
                    LinkifiedText(notes)
                        .font(.system(size: 12))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
        .environment(\.colorScheme, .light)
    }

    private var timeRangeText: String {
        if event.isAllDay { return "All day" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM, h:mm a"
        let start = formatter.string(from: event.startDate)
        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "h:mm a"
        let end = endFormatter.string(from: event.endDate)
        return "\(start) – \(end)"
    }
}

/// Renders text with any detected URLs (and phone numbers, since calendar
/// invites often include `tel:` dial-in links) turned into real tappable
/// links, using NSDataDetector rather than trying to hand-roll a regex.
private struct LinkifiedText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(Self.linkify(text))
    }

    private static func linkify(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        let types: UInt64 = NSTextCheckingResult.CheckingType.link.rawValue | NSTextCheckingResult.CheckingType.phoneNumber.rawValue
        guard let detector = try? NSDataDetector(types: types) else {
            return attributed
        }
        let nsText = text as NSString
        let matches = detector.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            let url: URL?
            if let matchURL = match.url {
                url = matchURL
            } else if let phoneNumber = match.phoneNumber {
                url = URL(string: "tel:\(phoneNumber.filter { !$0.isWhitespace })")
            } else {
                url = nil
            }
            guard let url, let attrRange = Range(range, in: attributed) else { continue }
            attributed[attrRange].link = url
            attributed[attrRange].foregroundColor = .accentColor
            attributed[attrRange].underlineStyle = .single
        }
        return attributed
    }
}
