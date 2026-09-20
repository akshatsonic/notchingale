import SwiftUI

struct TimerCardView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var timer: FocusTimerModel
    @State private var showSetTime = false
    @State private var customMinutes: Double = 25

    var body: some View {
        // No title/icon here — the reference removes the "Focus" header
        // entirely for this card, unlike the other three.
        CardContainer(title: "", tint: Theme.timerCard) {
            if showSetTime {
                setTimeInline
            } else {
                mainBody
            }
        }
    }

    private var mainBody: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 4)

            // Actual dot-matrix rendering (see DotMatrixText.swift) — each
            // digit drawn as a grid of dots rather than a system font, so
            // no font-file asset is needed to get the real LED look.
            DotMatrixText(
                text: timer.formattedRemaining,
                dotSize: 4,
                dotSpacing: 2,
                charSpacing: 5,
                onColor: Theme.cardTextPrimary.opacity(0.85),
                offColor: Theme.cardTextPrimary.opacity(0.08)
            )

            Text(timer.mode == .idle ? "Ready" : "Remaining")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.cardTextSecondary)

            Rectangle()
                .fill(Theme.cardTextSecondary.opacity(0.3))
                .frame(width: 40, height: 1)
                .padding(.vertical, 4)

            HStack(spacing: 10) {
                Button {
                    switch timer.mode {
                    case .idle: timer.start(minutes: Int(customMinutes), taskTitle: "Focus session")
                    case .running: timer.pause()
                    case .paused: timer.resume()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: timer.mode == .running ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text(timer.mode == .running ? "Pause" : "Start")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    if let session = timer.complete() {
                        store.recordFocusSession(taskTitle: session.taskTitle, startedAt: session.startedAt, durationSeconds: session.elapsed)
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(timer.mode == .idle)
                .opacity(timer.mode == .idle ? 0.4 : 1)
            }

            Spacer(minLength: 4)

            if timer.mode == .idle {
                Button {
                    showSetTime = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3").font(.system(size: 10))
                        Text("Set time").font(.system(size: 11.5))
                    }
                    .foregroundStyle(Theme.cardTextSecondary)
                }
                .buttonStyle(.plain)
            } else {
                Text("Today: \(formatted(store.totalFocusSecondsToday))")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.cardTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var setTimeInline: some View {
        VStack(spacing: 10) {
            Text("\(Int(customMinutes)) min")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.cardTextPrimary)
            Slider(value: $customMinutes, in: 5...90, step: 5)
            HStack {
                Button("Cancel") { showSetTime = false }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5))
                Spacer()
                Button("Done") {
                    timer.setTime(minutes: Int(customMinutes))
                    showSetTime = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 11.5, weight: .semibold))
            }
            .foregroundStyle(Theme.cardTextPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatted(_ seconds: Int) -> String {
        let m = seconds / 60
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h \(m % 60)m"
    }
}
