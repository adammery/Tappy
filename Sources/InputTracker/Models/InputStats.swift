import Foundation

struct KeyboardStats: Codable, Sendable {
    var totalKeystrokes: Int = 0
    var keyFrequency: [UInt16: Int] = [:]
    var recentTimestamps: [TimeInterval] = []

    var topKeys: [(keyCode: UInt16, count: Int)] {
        keyFrequency.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
    }

    var typingSpeed: Double {
        let now = Date().timeIntervalSince1970
        let recent = recentTimestamps.filter { now - $0 < 60.0 }
        return Double(recent.count)
    }

    mutating func trimTimestamps() {
        let now = Date().timeIntervalSince1970
        recentTimestamps.removeAll { now - $0 > 60.0 }
    }

    // Don't persist recentTimestamps — they're ephemeral
    enum CodingKeys: String, CodingKey {
        case totalKeystrokes, keyFrequency
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalKeystrokes = try c.decode(Int.self, forKey: .totalKeystrokes)
        keyFrequency = try c.decode([UInt16: Int].self, forKey: .keyFrequency)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(totalKeystrokes, forKey: .totalKeystrokes)
        try c.encode(keyFrequency, forKey: .keyFrequency)
    }
}

struct MouseStats: Codable, Sendable {
    var leftClicks: Int = 0
    var rightClicks: Int = 0
    var middleClicks: Int = 0

    var totalClicks: Int { leftClicks + rightClicks + middleClicks }
}
