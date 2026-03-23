@preconcurrency import CoreGraphics
@preconcurrency import CoreFoundation
import Foundation

struct EventBatch: Sendable {
    var keystrokes: [(keyCode: UInt16, timestamp: TimeInterval)] = []
    var leftClicks: Int = 0
    var rightClicks: Int = 0
    var middleClicks: Int = 0

    var isEmpty: Bool {
        keystrokes.isEmpty && leftClicks == 0 && rightClicks == 0 && middleClicks == 0
    }

    mutating func reset() {
        keystrokes.removeAll(keepingCapacity: true)
        leftClicks = 0
        rightClicks = 0
        middleClicks = 0
    }
}

final class EventMonitor: @unchecked Sendable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var monitorThread: Thread?
    private var flushTimer: Timer?
    private weak var statsManager: StatsManager?

    // Buffer guarded by lock — written on event thread, read on flush
    private let lock = NSLock()
    private var buffer = EventBatch()

    let flushInterval: TimeInterval

    init(statsManager: StatsManager, flushInterval: TimeInterval = 3.0) {
        self.statsManager = statsManager
        self.flushInterval = flushInterval
    }

    func start() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
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

        // Single timer flushes buffer to StatsManager
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            self?.flush()
        }
    }

    func stop() {
        flushTimer?.invalidate()
        flushTimer = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        flush()
        eventTap = nil
        runLoopSource = nil
        monitorThread?.cancel()
        monitorThread = nil
    }

    private func flush() {
        lock.lock()
        let batch = buffer
        buffer.reset()
        lock.unlock()

        guard !batch.isEmpty else { return }
        Task { @MainActor [weak statsManager] in
            statsManager?.applyBatch(batch)
        }
    }

    // Fast callback — only appends to buffer, no Task dispatch
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
        switch type {
        case .keyDown:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            monitor.buffer.keystrokes.append((keyCode, now))
        case .leftMouseDown:
            monitor.buffer.leftClicks += 1
        case .rightMouseDown:
            monitor.buffer.rightClicks += 1
        case .otherMouseDown:
            monitor.buffer.middleClicks += 1
        default:
            break
        }
        monitor.lock.unlock()

        return Unmanaged.passUnretained(event)
    }
}
