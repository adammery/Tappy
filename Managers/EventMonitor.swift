@preconcurrency import CoreGraphics
@preconcurrency import CoreFoundation
import Foundation
import AppKit

struct BatchAppCount: Sendable {
    var keystrokes: Int = 0
    var clicks: Int = 0
}

struct EventBatch: Sendable {
    var keystrokes: [(keyCode: UInt16, timestamp: TimeInterval)] = []
    var leftClicks: Int = 0
    var rightClicks: Int = 0
    var middleClicks: Int = 0
    var perApp: [String: BatchAppCount] = [:]

    var isEmpty: Bool {
        keystrokes.isEmpty && leftClicks == 0 && rightClicks == 0 && middleClicks == 0
    }

    mutating func reset() {
        keystrokes.removeAll(keepingCapacity: true)
        leftClicks = 0
        rightClicks = 0
        middleClicks = 0
        perApp.removeAll(keepingCapacity: true)
    }
}

final class EventMonitor: @unchecked Sendable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var monitorThread: Thread?
    private weak var statsManager: StatsManager?

    // Buffer guarded by lock — written on event thread, read on flush
    private let lock = NSLock()
    private var buffer = EventBatch()
    private var currentAppName: String = "Unknown"
    private var eventsSinceLastSave: Int = 0

    // UI timer: 4fps when menu is open
    private var uiTimer: Timer?

    private static let saveThreshold = 300

    init(statsManager: StatsManager) {
        self.statsManager = statsManager
    }

    func start() {
        guard eventTap == nil else { return }

        // Track frontmost app via workspace notification
        currentAppName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: EventMonitor.eventCallback,
            userInfo: userInfo
        ) else {
            print("[Tappy] Failed to create event tap — check Input Monitoring permission.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        let source = runLoopSource!
        monitorThread = Thread {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        monitorThread?.qualityOfService = .utility
        monitorThread?.name = "Tappy.EventMonitor"
        monitorThread?.start()
    }

    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let name = app.localizedName else { return }
        lock.lock()
        currentAppName = name
        lock.unlock()
    }

    /// Menu opened — flush + save, start 4fps UI timer
    /// Menu closed — stop timer, flush last batch
    func setLive(_ live: Bool) {
        if live {
            flushToUI()
            uiTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                self?.flushToUI()
            }
        } else {
            uiTimer?.invalidate()
            uiTimer = nil
            flushToUI()
        }
    }

    func stop() {
        uiTimer?.invalidate()
        uiTimer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        flushAndSave()
        eventTap = nil
        runLoopSource = nil
        monitorThread?.cancel()
        monitorThread = nil
    }

    /// Flush buffer → StatsManager (RAM only, no disk write)
    private func flushToUI() {
        lock.lock()
        let batch = buffer
        buffer.reset()
        lock.unlock()

        guard !batch.isEmpty else { return }
        #if DEBUG
        print("[Tappy] RAM flush: \(batch.keystrokes.count) keys, \(batch.leftClicks + batch.rightClicks + batch.middleClicks) clicks")
        #endif
        Task { @MainActor [weak statsManager] in
            statsManager?.applyBatch(batch)
        }
    }

    /// Flush buffer → StatsManager → UserDefaults (disk save)
    private func flushAndSave() {
        lock.lock()
        let batch = buffer
        buffer.reset()
        eventsSinceLastSave = 0
        lock.unlock()

        #if DEBUG
        print("[Tappy] DISK save: \(batch.keystrokes.count) keys buffered")
        #endif
        Task { @MainActor [weak statsManager] in
            if !batch.isEmpty {
                statsManager?.applyBatch(batch)
            }
            statsManager?.save()
        }
    }

    // Fast callback — appends to buffer, triggers threshold save
    private static let eventCallback: CGEventTapCallBack = {
        (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in

        guard let userInfo = userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let monitor = Unmanaged<EventMonitor>.fromOpaque(userInfo).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = monitor.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let now = Date().timeIntervalSince1970
        monitor.lock.lock()
        let appName = monitor.currentAppName

        switch type {
        case .keyDown:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            monitor.buffer.keystrokes.append((keyCode, now))
            monitor.buffer.perApp[appName, default: BatchAppCount()].keystrokes += 1
            monitor.eventsSinceLastSave += 1
        case .flagsChanged:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            let isDown = switch keyCode {
                case 54, 55: flags.contains(.maskCommand)
                case 56, 60: flags.contains(.maskShift)
                case 58, 61: flags.contains(.maskAlternate)
                case 59, 62: flags.contains(.maskControl)
                case 57: flags.contains(.maskAlphaShift)
                default: false
            }
            if isDown {
                monitor.buffer.keystrokes.append((keyCode, now))
                monitor.buffer.perApp[appName, default: BatchAppCount()].keystrokes += 1
                monitor.eventsSinceLastSave += 1
            }
        case .leftMouseDown:
            monitor.buffer.leftClicks += 1
            monitor.buffer.perApp[appName, default: BatchAppCount()].clicks += 1
            monitor.eventsSinceLastSave += 1
        case .rightMouseDown:
            monitor.buffer.rightClicks += 1
            monitor.buffer.perApp[appName, default: BatchAppCount()].clicks += 1
            monitor.eventsSinceLastSave += 1
        case .otherMouseDown:
            monitor.buffer.middleClicks += 1
            monitor.buffer.perApp[appName, default: BatchAppCount()].clicks += 1
            monitor.eventsSinceLastSave += 1
        default:
            break
        }

        let shouldSave = monitor.eventsSinceLastSave >= EventMonitor.saveThreshold
        monitor.lock.unlock()

        if shouldSave {
            DispatchQueue.main.async { [weak monitor] in
                monitor?.flushAndSave()
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
