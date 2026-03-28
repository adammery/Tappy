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

    // Today-only stats (reset on date change)
    var todayKeyboard = KeyboardStats()
    var todayMouse = MouseStats()
    var todayPerApp: [String: AppStats] = [:]
    var todayTopApps: [(name: String, stats: AppStats)] = []
    var todayActiveTime: TimeInterval = 0
    private var currentDay: String = ""
    private var todayUptimeBase = ProcessInfo.processInfo.systemUptime

    private let defaults = UserDefaults.standard
    private static let keyboardKey = "Tappy.keyboard"
    private static let mouseKey = "Tappy.mouse"
    private static let perAppKey = "Tappy.perApp"
    private static let activeTimeKey = "Tappy.totalActiveTime"
    private static let dailyHistoryKey = "Tappy.dailyHistory"
    private static let todayKeyboardKey = "Tappy.todayKeyboard"
    private static let todayMouseKey = "Tappy.todayMouse"
    private static let todayPerAppKey = "Tappy.todayPerApp"
    private static let todayActiveTimeKey = "Tappy.todayActiveTime"
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
        topApps = perApp.sorted { $0.value.totalInputs > $1.value.totalInputs }
            .prefix(5).map { ($0.key, $0.value) }
        todayTopApps = todayPerApp.sorted { $0.value.totalInputs > $1.value.totalInputs }
            .prefix(5).map { ($0.key, $0.value) }
    }

    // MARK: - Batch processing (called by EventMonitor flush)

    func applyBatch(_ batch: EventBatch) {
        // Check for date change (midnight reset)
        let today = todayKey
        if today != currentDay {
            resetToday()
            currentDay = today
        }

        // All-time stats
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

        // Today stats (mirror of all-time logic)
        for (keyCode, timestamp) in batch.keystrokes {
            todayKeyboard.totalKeystrokes += 1
            todayKeyboard.keyFrequency[keyCode, default: 0] += 1
            todayKeyboard.recentTimestamps.append(timestamp)
        }
        todayMouse.leftClicks += batch.leftClicks
        todayMouse.rightClicks += batch.rightClicks
        todayMouse.middleClicks += batch.middleClicks

        for (app, count) in batch.appKeystrokes {
            todayPerApp[app, default: AppStats()].keystrokes += count
        }
        for (app, count) in batch.appClicks {
            todayPerApp[app, default: AppStats()].clicks += count
        }

        keyboard.trimTimestamps()
        todayKeyboard.trimTimestamps()
        topApps = perApp.sorted { $0.value.totalInputs > $1.value.totalInputs }
            .prefix(5).map { ($0.key, $0.value) }
        todayTopApps = todayPerApp.sorted { $0.value.totalInputs > $1.value.totalInputs }
            .prefix(5).map { ($0.key, $0.value) }
        tick.toggle()
    }

    private func resetToday() {
        todayKeyboard = KeyboardStats()
        todayMouse = MouseStats()
        todayPerApp = [:]
        todayTopApps = []
        todayActiveTime = 0
        todayUptimeBase = ProcessInfo.processInfo.systemUptime
    }

    /// Sync today's live stats into dailyHistory — call before reading dailyHistory for Activity tab
    func syncTodayToHistory() {
        let today = todayKey
        let activeNow = todayActiveTime + ProcessInfo.processInfo.systemUptime - todayUptimeBase
        dailyHistory[today] = DailySnapshot(
            keystrokes: todayKeyboard.totalKeystrokes,
            clicks: todayMouse.totalClicks,
            activeSeconds: Int(activeNow),
            keyFrequency: todayKeyboard.keyFrequency,
            leftClicks: todayMouse.leftClicks,
            rightClicks: todayMouse.rightClicks,
            middleClicks: todayMouse.middleClicks,
            perApp: todayPerApp
        )

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

        // Today stats — only load if saved day matches today
        let savedDay = defaults.string(forKey: Self.currentDayKey) ?? ""
        if savedDay == todayKey {
            if let data = defaults.data(forKey: Self.todayKeyboardKey),
               let decoded = try? JSONDecoder().decode(KeyboardStats.self, from: data) {
                todayKeyboard = decoded
            }
            if let data = defaults.data(forKey: Self.todayMouseKey),
               let decoded = try? JSONDecoder().decode(MouseStats.self, from: data) {
                todayMouse = decoded
            }
            if let data = defaults.data(forKey: Self.todayPerAppKey),
               let decoded = try? JSONDecoder().decode([String: AppStats].self, from: data) {
                todayPerApp = decoded
            }
            todayActiveTime = defaults.double(forKey: Self.todayActiveTimeKey)
        }
    }

    func save() {
        let now = ProcessInfo.processInfo.systemUptime
        let uptimeDelta = now - uptimeAtLastSave
        totalActiveTime += uptimeDelta
        todayActiveTime += now - todayUptimeBase
        todayUptimeBase = now
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

        // Today stats persistence
        if let data = try? JSONEncoder().encode(todayKeyboard) {
            defaults.set(data, forKey: Self.todayKeyboardKey)
        }
        if let data = try? JSONEncoder().encode(todayMouse) {
            defaults.set(data, forKey: Self.todayMouseKey)
        }
        if let data = try? JSONEncoder().encode(todayPerApp) {
            defaults.set(data, forKey: Self.todayPerAppKey)
        }
        defaults.set(todayActiveTime, forKey: Self.todayActiveTimeKey)
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
        resetToday()
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
        save()
    }

    // MARK: - Uptime

    var systemUptime: String {
        _ = tick
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    var totalActiveTimeFormatted: String {
        _ = tick
        let total = totalActiveTime + ProcessInfo.processInfo.systemUptime - uptimeAtLastSave
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    var todayActiveTimeFormatted: String {
        _ = tick
        let total = todayActiveTime + ProcessInfo.processInfo.systemUptime - todayUptimeBase
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
