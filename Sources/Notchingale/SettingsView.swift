import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var launchAtLogin = false
    @State private var showResetConfirm = false

    var body: some View {
        Form {
            Section("Workspace cards") {
                Toggle("Tasks", isOn: $settings.showTasks)
                Toggle("Focus", isOn: $settings.showFocus)
                Toggle("Notepad", isOn: $settings.showNotes)
                Toggle("Events", isOn: $settings.showEvents)
                Text("The window resizes automatically to fit whichever cards are on.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Launch Notchingale at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            Section {
                Button("Reset all data…", role: .destructive) {
                    showResetConfirm = true
                }
            }

            Section {
                Text("Notchingale 1.0 — a from-scratch clone built for learning purposes. Not affiliated with NotchOwl.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .onAppear {
            if #available(macOS 13.0, *) {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
        .alert("Reset all data?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                NotificationCenter.default.post(name: .notchingaleResetData, object: nil)
            }
        } message: {
            Text("This deletes every task, note, and focus session. This can't be undone.")
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Registration can fail if the app isn't signed/installed in
            // /Applications; the toggle simply won't stick in that case.
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

extension Notification.Name {
    static let notchingaleResetData = Notification.Name("notchingaleResetData")
}
