import Foundation
import AppKit
import CryptoKit
import Observation
import UniformTypeIdentifiers

struct ExportData: Codable {
    var keyboard: KeyboardStats
    var mouse: MouseStats
    var perApp: [String: AppStats]
    var totalActiveTime: TimeInterval
    var exportedAt: Date
    var dailyHistory: [String: DailySnapshot]?
}

private enum Crypto {
    private static let keyData = Data("Tappy!secret!!v1!extra!secure32!".utf8)
    private static var key: SymmetricKey { SymmetricKey(data: keyData) }

    static func encrypt(_ data: Data) throws -> Data {
        let sealed = try AES.GCM.seal(data, using: key)
        return sealed.combined!
    }

    static func decrypt(_ data: Data) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }
}


@Observable
@MainActor
final class StatsManager {
    var keyboard = KeyboardStats()
    var mouse = MouseStats()
    var perApp: [String: AppStats] = [:]
    var topApps: [(name: String, stats: AppStats)] = []
    var totalActiveTime: TimeInterval = 0
    var dailyHistory: [String: DailySnapshot] = [:]
    private var uptimeAtLastSave = ProcessInfo.processInfo.systemUptime
    var tick: Bool = false

    // Session stats (manual reset only)
    var sessionKeyboard = KeyboardStats()
    var sessionMouse = MouseStats()
    var sessionPerApp: [String: AppStats] = [:]
    var sessionTopApps: [(name: String, stats: AppStats)] = []
    var sessionActiveTime: TimeInterval = 0
    private var currentDay: String = ""
    private var sessionUptimeBase = ProcessInfo.processInfo.systemUptime
    private var dailyCommitted = DailySnapshot()

    private let defaults = UserDefaults.standard
    private static let keyboardKey = "Tappy.keyboard"
    private static let mouseKey = "Tappy.mouse"
    private static let perAppKey = "Tappy.perApp"
    private static let activeTimeKey = "Tappy.totalActiveTime"
    private static let dailyHistoryKey = "Tappy.dailyHistory"
    private static let sessionKeyboardKey = "Tappy.sessionKeyboard"
    private static let sessionMouseKey = "Tappy.sessionMouse"
    private static let sessionPerAppKey = "Tappy.sessionPerApp"
    private static let sessionActiveTimeKey = "Tappy.sessionActiveTime"
    private static let dailyCommittedKey = "Tappy.dailyCommitted"
    private static let currentDayKey = "Tappy.currentDay"

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var todayKey: String { Self.dayFormatter.string(from: Date()) }

    init() {
        currentDay = todayKey
        loadStats()
        updateTopApps()
    }

    // MARK: - Batch processing (called by EventMonitor flush)

    func applyBatch(_ batch: EventBatch) {
        checkDayChange()
        applyToStats(keyboard: &keyboard, mouse: &mouse, perApp: &perApp, batch: batch)
        applyToStats(keyboard: &sessionKeyboard, mouse: &sessionMouse, perApp: &sessionPerApp, batch: batch)
        keyboard.trimTimestamps()
        sessionKeyboard.trimTimestamps()
        updateTopApps()
        tick.toggle()
    }

    /// Detect midnight crossing — commit session to yesterday, start fresh
    private func checkDayChange() {
        let today = todayKey
        guard today != currentDay else { return }
        // Commit current session to old day
        var snap = dailyCommitted
        snap.merge(currentSessionSnapshot())
        dailyHistory[currentDay] = snap
        // Reset for new day
        dailyCommitted = DailySnapshot()
        sessionKeyboard = KeyboardStats()
        sessionMouse = MouseStats()
        sessionPerApp = [:]
        sessionTopApps = []
        sessionActiveTime = 0
        sessionUptimeBase = ProcessInfo.processInfo.systemUptime
        currentDay = today
    }

    private func applyToStats(keyboard: inout KeyboardStats, mouse: inout MouseStats,
                              perApp: inout [String: AppStats], batch: EventBatch) {
        for (keyCode, timestamp) in batch.keystrokes {
            keyboard.totalKeystrokes += 1
            keyboard.keyFrequency[keyCode, default: 0] += 1
            keyboard.recentTimestamps.append(timestamp)
        }
        mouse.leftClicks += batch.leftClicks
        mouse.rightClicks += batch.rightClicks
        mouse.middleClicks += batch.middleClicks
        for (app, count) in batch.appKeystrokes {
            perApp[app, default: AppStats()].keystrokes += count
        }
        for (app, count) in batch.appClicks {
            perApp[app, default: AppStats()].clicks += count
        }
    }

    private func updateTopApps() {
        topApps = perApp.sorted { $0.value.totalInputs > $1.value.totalInputs }
            .prefix(5).map { ($0.key, $0.value) }
        sessionTopApps = sessionPerApp.sorted { $0.value.totalInputs > $1.value.totalInputs }
            .prefix(5).map { ($0.key, $0.value) }
    }

    private func currentSessionSnapshot() -> DailySnapshot {
        let activeNow = sessionActiveTime + ProcessInfo.processInfo.systemUptime - sessionUptimeBase
        return DailySnapshot(
            keystrokes: sessionKeyboard.totalKeystrokes,
            clicks: sessionMouse.totalClicks,
            activeSeconds: Int(activeNow),
            keyFrequency: sessionKeyboard.keyFrequency,
            leftClicks: sessionMouse.leftClicks,
            rightClicks: sessionMouse.rightClicks,
            middleClicks: sessionMouse.middleClicks,
            perApp: sessionPerApp
        )
    }

    func resetSession() {
        syncTodayToHistory()
        dailyCommitted.merge(currentSessionSnapshot())
        sessionKeyboard = KeyboardStats()
        sessionMouse = MouseStats()
        sessionPerApp = [:]
        sessionTopApps = []
        sessionActiveTime = 0
        sessionUptimeBase = ProcessInfo.processInfo.systemUptime
        save()
    }

    /// Sync today's live stats into dailyHistory — call before reading dailyHistory for Activity tab
    func syncTodayToHistory() {
        checkDayChange()
        let today = todayKey
        var snap = dailyCommitted
        snap.merge(currentSessionSnapshot())
        dailyHistory[today] = snap

        // Drop entries older than 365 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -365, to: Date())!
        let cutoffKey = Self.dayFormatter.string(from: cutoff)
        dailyHistory = dailyHistory.filter { $0.key >= cutoffKey }
    }

    // MARK: - Persistence

    private func loadStats() {
        if let data = defaults.data(forKey: Self.keyboardKey),
           let decoded = try? JSONDecoder().decode(KeyboardStats.self, from: data) {
            keyboard = decoded
        }
        if let data = defaults.data(forKey: Self.mouseKey),
           let decoded = try? JSONDecoder().decode(MouseStats.self, from: data) {
            mouse = decoded
        }
        if let data = defaults.data(forKey: Self.perAppKey),
           let decoded = try? JSONDecoder().decode([String: AppStats].self, from: data) {
            perApp = decoded
        }
        totalActiveTime = defaults.double(forKey: Self.activeTimeKey)
        if let data = defaults.data(forKey: Self.dailyHistoryKey),
           let decoded = try? JSONDecoder().decode([String: DailySnapshot].self, from: data) {
            dailyHistory = decoded
        }

        // Session + committed — only load if saved day matches today
        let savedDay = defaults.string(forKey: Self.currentDayKey) ?? ""
        if savedDay == todayKey {
            if let data = defaults.data(forKey: Self.sessionKeyboardKey),
               let decoded = try? JSONDecoder().decode(KeyboardStats.self, from: data) {
                sessionKeyboard = decoded
            }
            if let data = defaults.data(forKey: Self.sessionMouseKey),
               let decoded = try? JSONDecoder().decode(MouseStats.self, from: data) {
                sessionMouse = decoded
            }
            if let data = defaults.data(forKey: Self.sessionPerAppKey),
               let decoded = try? JSONDecoder().decode([String: AppStats].self, from: data) {
                sessionPerApp = decoded
            }
            sessionActiveTime = defaults.double(forKey: Self.sessionActiveTimeKey)
            if let data = defaults.data(forKey: Self.dailyCommittedKey),
               let decoded = try? JSONDecoder().decode(DailySnapshot.self, from: data) {
                dailyCommitted = decoded
            }
        }
    }

    func save() {
        let now = ProcessInfo.processInfo.systemUptime
        let uptimeDelta = now - uptimeAtLastSave
        totalActiveTime += uptimeDelta
        sessionActiveTime += now - sessionUptimeBase
        sessionUptimeBase = now
        uptimeAtLastSave = now

        if let data = try? JSONEncoder().encode(keyboard) {
            defaults.set(data, forKey: Self.keyboardKey)
        }
        if let data = try? JSONEncoder().encode(mouse) {
            defaults.set(data, forKey: Self.mouseKey)
        }
        if let data = try? JSONEncoder().encode(perApp) {
            defaults.set(data, forKey: Self.perAppKey)
        }
        defaults.set(totalActiveTime, forKey: Self.activeTimeKey)

        if let data = try? JSONEncoder().encode(dailyHistory) {
            defaults.set(data, forKey: Self.dailyHistoryKey)
        }

        // Session stats persistence
        if let data = try? JSONEncoder().encode(sessionKeyboard) {
            defaults.set(data, forKey: Self.sessionKeyboardKey)
        }
        if let data = try? JSONEncoder().encode(sessionMouse) {
            defaults.set(data, forKey: Self.sessionMouseKey)
        }
        if let data = try? JSONEncoder().encode(sessionPerApp) {
            defaults.set(data, forKey: Self.sessionPerAppKey)
        }
        defaults.set(sessionActiveTime, forKey: Self.sessionActiveTimeKey)
        if let data = try? JSONEncoder().encode(dailyCommitted) {
            defaults.set(data, forKey: Self.dailyCommittedKey)
        }
        defaults.set(currentDay, forKey: Self.currentDayKey)
    }

    func resetStats() {
        keyboard = KeyboardStats()
        mouse = MouseStats()
        perApp = [:]
        topApps = []
        totalActiveTime = 0
        dailyHistory = [:]
        uptimeAtLastSave = ProcessInfo.processInfo.systemUptime
        sessionKeyboard = KeyboardStats()
        sessionMouse = MouseStats()
        sessionPerApp = [:]
        sessionTopApps = []
        sessionActiveTime = 0
        sessionUptimeBase = ProcessInfo.processInfo.systemUptime
        dailyCommitted = DailySnapshot()
        currentDay = todayKey
        save()
    }

    // MARK: - Export / Import

    func exportStats() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Tappy-backup.itbackup"
        panel.allowedContentTypes = [.data]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let export = ExportData(keyboard: keyboard, mouse: mouse, perApp: perApp, totalActiveTime: totalActiveTime + ProcessInfo.processInfo.systemUptime - uptimeAtLastSave, exportedAt: Date(), dailyHistory: dailyHistory)
        guard let json = try? JSONEncoder().encode(export),
              let encrypted = try? Crypto.encrypt(json) else { return }
        try? encrypted.write(to: url)
    }

    func importStats() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.data]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let encrypted = try? Data(contentsOf: url),
              let json = try? Crypto.decrypt(encrypted),
              let imported = try? JSONDecoder().decode(ExportData.self, from: json) else { return }

        keyboard = imported.keyboard
        mouse = imported.mouse
        perApp = imported.perApp
        totalActiveTime = imported.totalActiveTime
        dailyHistory = imported.dailyHistory ?? [:]
        uptimeAtLastSave = ProcessInfo.processInfo.systemUptime
        updateTopApps()
        save()
    }

    // MARK: - Uptime

    var systemUptime: String {
        _ = tick
        return Int(ProcessInfo.processInfo.systemUptime).formattedTime
    }

    var totalActiveTimeFormatted: String {
        _ = tick
        let total = totalActiveTime + ProcessInfo.processInfo.systemUptime - uptimeAtLastSave
        return Int(total).formattedTime
    }

    var sessionActiveTimeFormatted: String {
        _ = tick
        let total = sessionActiveTime + ProcessInfo.processInfo.systemUptime - sessionUptimeBase
        return Int(total).formattedTime
    }

}
