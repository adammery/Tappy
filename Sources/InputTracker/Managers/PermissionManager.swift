import CoreGraphics
import AppKit
import Observation

@Observable
final class PermissionManager: @unchecked Sendable {
    var hasPermission: Bool = false

    func checkPermission() {
        hasPermission = CGPreflightListenEventAccess()
    }

    func requestPermission() {
        CGRequestListenEventAccess()
        checkPermission()
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
