import Foundation
import CoreGraphics
import AppKit
import CryptoKit
import Observation
import UniformTypeIdentifiers

struct ExportData: Codable {
    var keyboard: KeyboardStats
    var mouse: MouseStats
    var exportedAt: Date
}

private enum Crypto {
    private static let keyData = Data("InputTracker!!v1".utf8)
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

private let itbackupType = UTType(exportedAs: "com.local.inputtracker.backup", conformingTo: .data)

@Observable
@MainActor
final class StatsManager {
    var keyboard = KeyboardStats()
    var mouse = MouseStats()
    var sessionStart = Date()
    var tick: Bool = false

    private var saveTimer: Timer?
    private let defaults = UserDefaults.standard
    private static let keyboardKey = "InputTracker.keyboard"
    private static let mouseKey = "InputTracker.mouse"

    init() {
        loadStats()
        // Single timer: auto-save every 5 minutes
        saveTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.saveStats() }
        }
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

        // Trim old timestamps inline
        keyboard.trimTimestamps()
        // Toggle tick to refresh uptime display
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
    }

    private func saveStats() {
        if let data = try? JSONEncoder().encode(keyboard) {
            defaults.set(data, forKey: Self.keyboardKey)
        }
        if let data = try? JSONEncoder().encode(mouse) {
            defaults.set(data, forKey: Self.mouseKey)
        }
    }

    func resetStats() {
        keyboard = KeyboardStats()
        mouse = MouseStats()
        sessionStart = Date()
        saveStats()
    }

    func save() {
        saveStats()
    }

    // MARK: - Export / Import

    func exportStats() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "InputTracker-backup.itbackup"
        panel.allowedContentTypes = [itbackupType]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let export = ExportData(keyboard: keyboard, mouse: mouse, exportedAt: Date())
        guard let json = try? JSONEncoder().encode(export),
              let encrypted = try? Crypto.encrypt(json) else { return }
        try? encrypted.write(to: url)
    }

    func importStats() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [itbackupType]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let encrypted = try? Data(contentsOf: url),
              let json = try? Crypto.decrypt(encrypted),
              let imported = try? JSONDecoder().decode(ExportData.self, from: json) else { return }

        keyboard = imported.keyboard
        mouse = imported.mouse
        saveStats()
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

    var sessionDuration: String {
        _ = tick
        let elapsed = Date().timeIntervalSince(sessionStart)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
