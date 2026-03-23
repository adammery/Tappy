import SwiftUI

struct KeyboardStatsView: View {
    let keyboard: KeyboardStats

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Keyboard", systemImage: "keyboard")
                .font(.headline)

            StatRow(label: "Keystrokes", value: keyboard.totalKeystrokes.compact)
            StatRow(label: "Speed", value: "\(Int(keyboard.typingSpeed)) keys/min")

            KeyboardHeatmapView(keyFrequency: keyboard.keyFrequency)
                .padding(.top, 2)
        }
    }
}
