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
    private var uptimeAtLastSave = ProcessInfo.processInfo.systemUptime
    var tick: Bool = false

    private let defaults = UserDefaults.standard
    private static let keyboardKey = "Tappy.keyboard"
    private static let mouseKey = "Tappy.mouse"
    private static let perAppKey = "Tappy.perApp"
    private static let activeTimeKey = "Tappy.totalActiveTime"

    init() {
        loadStats()
    }

    // MARK: - Batch processing (called by EventMonitor flush)

    func applyBatch(_ batch: EventBatch) {
        for (keyCode, timestamp) in batch.keystrokes {
            keyboard.totalKeystrokes += 1
            keyboard.keyFrequency[keyCode, default: 0] += 1
            keyboard.recentTimestamps.append(timestamp)
        }
        mouse.leftClicks += batch.leftClicks
        mouse.rightClicks += batch.rightClicks
        mouse.middleClicks += batch.middleClicks

        // Per-app stats
        for (app, count) in batch.appKeystrokes {
            perApp[app, default: AppStats()].keystrokes += count
        }
        for (app, count) in batch.appClicks {
            perApp[app, default: AppStats()].clicks += count
        }

        keyboard.trimTimestamps()
        topApps = perApp.sorted { $0.value.totalInputs > $1.value.totalInputs }
            .prefix(5).map { ($0.key, $0.value) }
        tick.toggle()
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
    }

    func save() {
        let now = ProcessInfo.processInfo.systemUptime
        totalActiveTime += now - uptimeAtLastSave
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
    }

    func resetStats() {
        keyboard = KeyboardStats()
        mouse = MouseStats()
        perApp = [:]
        topApps = []
        totalActiveTime = 0
        uptimeAtLastSave = ProcessInfo.processInfo.systemUptime
        save()
    }

    // MARK: - Export / Import

    func exportStats() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Tappy-backup.itbackup"
        panel.allowedContentTypes = [.data]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let export = ExportData(keyboard: keyboard, mouse: mouse, perApp: perApp, totalActiveTime: totalActiveTime + ProcessInfo.processInfo.systemUptime - uptimeAtLastSave, exportedAt: Date())
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
}
