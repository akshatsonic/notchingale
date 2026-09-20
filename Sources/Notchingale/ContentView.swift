import SwiftUI

struct ContentView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var uiState: AppUIState
    @ObservedObject var timer: FocusTimerModel
    @ObservedObject var calendarService: CalendarService
    @ObservedObject var settings: AppSettings
    /// nil when already showing inside the full window (hides the "Open app" button then).
    var openFullWindow: (() -> Void)? = nil
    /// nil when there's nothing sensible to close (the full standalone window).
    var onClose: (() -> Void)? = nil
    /// Reports hover in/out over the popover content, so it can be kept
    /// open while the pointer is over it and closed shortly after it
    /// leaves. nil for the full standalone window, which doesn't need this.
    var onHoverChanged: ((Bool) -> Void)? = nil
    /// See WorkspaceView/EventsCardView — bubbles up further still, all
    /// the way to AppDelegate.
    var onChildPopoverChanged: ((Bool) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            topNav
            Divider().overlay(Color.white.opacity(0.08))

            Group {
                switch uiState.selectedTab {
                case .workspace:
                    WorkspaceView(store: store, timer: timer, calendarService: calendarService, settings: settings, onChildPopoverChanged: onChildPopoverChanged)
                case .insights:
                    InsightsView(store: store)
                case .settings:
                    SettingsView(settings: settings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(.white)
        .frame(minWidth: 480, minHeight: 340)
        .background(
            ZStack {
                VibrantBackground(material: .hudWindow)
                Color.black.opacity(0.45) // darken the HUD material toward the reference's near-black housing
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.outerRadius, style: .continuous))
        .onHover { hovering in
            onHoverChanged?(hovering)
        }
    }

    private var topNav: some View {
        HStack(spacing: 10) {
            AppLogo(size: 15)
                .foregroundStyle(.white)
            Text("Notchingale")
                .font(.system(size: 14, weight: .bold))

            if let openFullWindow {
                Button(action: openFullWindow) {
                    HStack(spacing: 4) {
                        Image(systemName: "macwindow")
                            .font(.system(size: 10))
                        Text("Open app")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Dark capsule segmented control, custom-drawn to match the
            // reference rather than the system .segmented picker style.
            HStack(spacing: 2) {
                ForEach(AppUIState.Tab.allCases) { tab in
                    Button {
                        uiState.selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: uiState.selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(uiState.selectedTab == tab ? .white : .white.opacity(0.55))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                uiState.selectedTab == tab ? Color.white.opacity(0.16) : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Spacer()

            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
