import SwiftUI

@main
struct InputTrackerApp: App {
    @State private var statsManager = StatsManager()
    @State private var permissionManager = PermissionManager()
    @State private var updateChecker = UpdateChecker()
    @State private var eventMonitor: EventMonitor?

    var body: some Scene {
        MenuBarExtra("InputTracker", systemImage: "keyboard") {
            MenuBarView(
                stats: statsManager,
                permission: permissionManager,
                updateChecker: updateChecker,
                onStart: startMonitoring
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
