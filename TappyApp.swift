import SwiftUI
import AppKit

@main
struct TappyApp: App {
    @State private var statsManager = StatsManager()
    @State private var permissionManager = PermissionManager()
    @State private var updateChecker = UpdateChecker()
    @State private var eventMonitor: EventMonitor?

    init() {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.adammery.Tappy")
        if running.count > 1 {
            NSApp.terminate(nil)
        }
    }

    var body: some Scene {
        MenuBarExtra("Tappy", systemImage: "keyboard") {
            MenuBarView(
                stats: statsManager,
                permission: permissionManager,
                updateChecker: updateChecker,
                onStart: startMonitoring,
                onLive: { live in eventMonitor?.setLive(live) }
            )
        }
        .menuBarExtraStyle(.window)
    }

    private func startMonitoring() {
        guard eventMonitor == nil else { return }
        let monitor = EventMonitor(statsManager: statsManager)
        monitor.start()
        eventMonitor = monitor
    }
}
