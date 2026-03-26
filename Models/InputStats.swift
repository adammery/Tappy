import Foundation

struct KeyboardStats: Codable, Sendable {
    var totalKeystrokes: Int = 0
    var keyFrequency: [UInt16: Int] = [:]
    var recentTimestamps: [TimeInterval] = []
    var typingSpeed: Double = 0

    mutating func trimTimestamps() {
        let now = Date().timeIntervalSince1970
        recentTimestamps.removeAll { now - $0 > 60.0 }
        if recentTimestamps.count > 1000 {
            recentTimestamps.removeFirst(recentTimestamps.count - 1000)
        }
        typingSpeed = Double(recentTimestamps.count)
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

struct AppStats: Codable, Sendable {
    var keystrokes: Int = 0
    var clicks: Int = 0
    var totalInputs: Int { keystrokes + clicks }
}
