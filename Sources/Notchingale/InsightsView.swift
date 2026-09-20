import SwiftUI

private enum InsightsMode: String, CaseIterable {
    case tasks = "Tasks"
    case focus = "Focus"
}

struct InsightsView: View {
    @ObservedObject var store: AppStore
    @State private var mode: InsightsMode = .tasks
    @State private var hoveredDay: Date? = nil

    private var stats: [AppStore.DayStat] { store.dayStats() }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SummaryCard(mode: mode, stats: stats, hoveredDay: hoveredDay, currentStreak: store.currentStreak) {
                hoveredDay = nil
            }
            .frame(width: 220)

            ChartCard(mode: $mode, stats: stats, hoveredDay: $hoveredDay)
                .frame(maxWidth: .infinity)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Left card: dynamic summary

private struct SummaryCard: View {
    let mode: InsightsMode
    let stats: [AppStore.DayStat]
    let hoveredDay: Date?
    let currentStreak: Int
    let onShowWholeWeek: () -> Void

    private var selectedStat: AppStore.DayStat? {
        guard let hoveredDay else { return nil }
        return stats.first { Calendar.current.isDate($0.day, inSameDayAs: hoveredDay) }
    }

    private var totalCompleted: Int { stats.reduce(0) { $0 + $1.completedTasks } }
    private var totalPlanned: Int { stats.reduce(0) { $0 + $1.plannedTasks } }
    private var totalFocusMinutes: Int { stats.reduce(0) { $0 + $1.focusMinutes } }
    private var activeDays: Int { stats.filter { $0.completedTasks > 0 || $0.focusMinutes > 0 }.count }

    var body: some View {
        CardContainer(title: headerText, tint: Theme.taskCard) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryMetric)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.cardTextPrimary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.cardTextSecondary)
                }

                if mode == .tasks {
                    let planned = selectedStat?.plannedTasks ?? totalPlanned
                    let completed = selectedStat?.completedTasks ?? totalCompleted
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.black.opacity(0.12))
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.black.opacity(0.55))
                                        .frame(width: planned > 0 ? geo.size.width * CGFloat(completed) / CGFloat(planned) : 0)
                                }
                        }
                        .frame(height: 5)
                        Text("of \(planned) planned")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.cardTextSecondary)
                    }
                }

                DottedDivider()

                VStack(spacing: 6) {
                    statRow("Focus time", formatMinutes(selectedStat?.focusMinutes ?? totalFocusMinutes))
                    statRow("Active days", "\(activeDays)")
                    statRow("Current streak", "\(currentStreak)d")
                }

                Spacer(minLength: 0)

                if hoveredDay != nil {
                    Button(action: onShowWholeWeek) {
                        Text("Show whole week")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.cardTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var headerText: String {
        guard let day = hoveredDay else { return "Last 7 days" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM"
        return formatter.string(from: day)
    }

    private var primaryMetric: String {
        if let selectedStat {
            return mode == .tasks ? "\(selectedStat.completedTasks)" : formatMinutes(selectedStat.focusMinutes)
        }
        return mode == .tasks ? "\(totalCompleted)" : formatMinutes(totalFocusMinutes)
    }

    private var subtitle: String {
        mode == .tasks ? "Tasks completed" : "Time focused"
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11.5)).foregroundStyle(Theme.cardTextSecondary)
            Spacer()
            Text(value).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Theme.cardTextPrimary)
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

// MARK: - Right card: interactive chart

private struct ChartCard: View {
    @Binding var mode: InsightsMode
    let stats: [AppStore.DayStat]
    @Binding var hoveredDay: Date?

    var body: some View {
        CardContainer(title: "", tint: Theme.timerCard) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    modeSwitcher
                    Spacer()
                    Text(dateRangeLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.cardTextSecondary)
                }

                chartArea
                    .frame(maxHeight: .infinity)

                HStack {
                    if mode == .tasks {
                        HStack(spacing: 10) {
                            legendItem(color: Color.black.opacity(0.6), label: "Completed")
                            legendItem(color: Color.black.opacity(0.18), label: "Planned")
                        }
                    }
                    Spacer()
                    Text(hoveredDay == nil ? "Select a day ▾" : "Change day ▾")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.cardTextSecondary)
                }
            }
        }
    }

    private var modeSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(InsightsMode.allCases, id: \.self) { m in
                Button {
                    mode = m
                } label: {
                    Text(m.rawValue)
                        .font(.system(size: 11.5, weight: mode == m ? .semibold : .regular))
                        .foregroundStyle(mode == m ? .white : .white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(mode == m ? Color.black.opacity(0.7) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.black.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var dateRangeLabel: String {
        guard let first = stats.first?.day, let last = stats.last?.day else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: first)) - \(formatter.string(from: last))"
    }

    private var maxValue: Int {
        switch mode {
        case .tasks: return max(stats.map(\.plannedTasks).max() ?? 1, 1)
        case .focus: return max(stats.map(\.focusMinutes).max() ?? 1, 1)
        }
    }

    private var chartArea: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(stats) { stat in
                BarColumn(
                    stat: stat,
                    mode: mode,
                    maxValue: maxValue,
                    isHovered: hoveredDay.map { Calendar.current.isDate($0, inSameDayAs: stat.day) } ?? false
                )
                .onHover { isHovering in
                    let alreadyThisDay = hoveredDay.map { Calendar.current.isDate($0, inSameDayAs: stat.day) } ?? false
                    hoveredDay = isHovering ? stat.day : (alreadyThisDay ? nil : hoveredDay)
                }
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 7, height: 7)
            Text(label).font(.system(size: 9.5))
        }
        .foregroundStyle(Theme.cardTextSecondary)
    }
}

private struct BarColumn: View {
    let stat: AppStore.DayStat
    let mode: InsightsMode
    let maxValue: Int
    let isHovered: Bool

    private let maxBarHeight: CGFloat = 84

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                switch mode {
                case .tasks:
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.18))
                        .frame(height: barHeight(for: stat.plannedTasks))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.6))
                        .frame(height: barHeight(for: stat.completedTasks))
                case .focus:
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.55))
                        .frame(height: barHeight(for: stat.focusMinutes))
                }
            }
            .frame(height: maxBarHeight, alignment: .bottom)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isHovered ? Color.black.opacity(0.8) : .clear, lineWidth: 1.5)
            )

            VStack(spacing: 0) {
                Text(dayAbbreviation).font(.system(size: 9.5, weight: .medium))
                Text(dayNumber).font(.system(size: 9))
            }
            .foregroundStyle(isHovered ? Theme.cardTextPrimary : Theme.cardTextSecondary)
        }
        .contentShape(Rectangle())
    }

    private func barHeight(for value: Int) -> CGFloat {
        guard maxValue > 0 else { return 0 }
        return max(CGFloat(value) / CGFloat(maxValue) * maxBarHeight, value > 0 ? 3 : 0)
    }

    private var dayAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: stat.day)
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: stat.day)
    }
}
