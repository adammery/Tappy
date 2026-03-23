import SwiftUI
import Carbon.HIToolbox

struct KeyDef {
    let label: String
    let keyCode: UInt16
    let width: CGFloat // relative width, 1.0 = standard key

    init(_ label: String, _ keyCode: UInt16, width: CGFloat = 1.0) {
        self.label = label
        self.keyCode = keyCode
        self.width = width
    }
}

struct KeyboardHeatmapView: View {
    let keyFrequency: [UInt16: Int]

    private let keySize: CGFloat = 18
    private let spacing: CGFloat = 2

    private var maxCount: Int {
        keyFrequency.values.max() ?? 1
    }

    private static let rows: [[KeyDef]] = [
        [
            KeyDef("`", UInt16(kVK_ANSI_Grave)),
            KeyDef("1", UInt16(kVK_ANSI_1)),
            KeyDef("2", UInt16(kVK_ANSI_2)),
            KeyDef("3", UInt16(kVK_ANSI_3)),
            KeyDef("4", UInt16(kVK_ANSI_4)),
            KeyDef("5", UInt16(kVK_ANSI_5)),
            KeyDef("6", UInt16(kVK_ANSI_6)),
            KeyDef("7", UInt16(kVK_ANSI_7)),
            KeyDef("8", UInt16(kVK_ANSI_8)),
            KeyDef("9", UInt16(kVK_ANSI_9)),
            KeyDef("0", UInt16(kVK_ANSI_0)),
            KeyDef("-", UInt16(kVK_ANSI_Minus)),
            KeyDef("=", UInt16(kVK_ANSI_Equal)),
            KeyDef("Del", UInt16(kVK_Delete), width: 1.5),
        ],
        [
            KeyDef("Tab", UInt16(kVK_Tab), width: 1.5),
            KeyDef("Q", UInt16(kVK_ANSI_Q)),
            KeyDef("W", UInt16(kVK_ANSI_W)),
            KeyDef("E", UInt16(kVK_ANSI_E)),
            KeyDef("R", UInt16(kVK_ANSI_R)),
            KeyDef("T", UInt16(kVK_ANSI_T)),
            KeyDef("Y", UInt16(kVK_ANSI_Y)),
            KeyDef("U", UInt16(kVK_ANSI_U)),
            KeyDef("I", UInt16(kVK_ANSI_I)),
            KeyDef("O", UInt16(kVK_ANSI_O)),
            KeyDef("P", UInt16(kVK_ANSI_P)),
            KeyDef("[", UInt16(kVK_ANSI_LeftBracket)),
            KeyDef("]", UInt16(kVK_ANSI_RightBracket)),
            KeyDef("\\", UInt16(kVK_ANSI_Backslash)),
        ],
        [
            KeyDef("Caps", UInt16(kVK_CapsLock), width: 1.8),
            KeyDef("A", UInt16(kVK_ANSI_A)),
            KeyDef("S", UInt16(kVK_ANSI_S)),
            KeyDef("D", UInt16(kVK_ANSI_D)),
            KeyDef("F", UInt16(kVK_ANSI_F)),
            KeyDef("G", UInt16(kVK_ANSI_G)),
            KeyDef("H", UInt16(kVK_ANSI_H)),
            KeyDef("J", UInt16(kVK_ANSI_J)),
            KeyDef("K", UInt16(kVK_ANSI_K)),
            KeyDef("L", UInt16(kVK_ANSI_L)),
            KeyDef(";", UInt16(kVK_ANSI_Semicolon)),
            KeyDef("'", UInt16(kVK_ANSI_Quote)),
            KeyDef("Ret", UInt16(kVK_Return), width: 1.7),
        ],
        [
            KeyDef("Shift", UInt16(kVK_Shift), width: 2.3),
            KeyDef("Z", UInt16(kVK_ANSI_Z)),
            KeyDef("X", UInt16(kVK_ANSI_X)),
            KeyDef("C", UInt16(kVK_ANSI_C)),
            KeyDef("V", UInt16(kVK_ANSI_V)),
            KeyDef("B", UInt16(kVK_ANSI_B)),
            KeyDef("N", UInt16(kVK_ANSI_N)),
            KeyDef("M", UInt16(kVK_ANSI_M)),
            KeyDef(",", UInt16(kVK_ANSI_Comma)),
            KeyDef(".", UInt16(kVK_ANSI_Period)),
            KeyDef("/", UInt16(kVK_ANSI_Slash)),
            KeyDef("Shift", UInt16(kVK_RightShift), width: 2.2),
        ],
        [
            KeyDef("Ctrl", UInt16(kVK_Control), width: 1.3),
            KeyDef("Opt", UInt16(kVK_Option), width: 1.3),
            KeyDef("Cmd", UInt16(kVK_Command), width: 1.5),
            KeyDef("", UInt16(kVK_Space), width: 5.0),
            KeyDef("Cmd", UInt16(kVK_RightCommand), width: 1.5),
            KeyDef("Opt", UInt16(kVK_RightOption), width: 1.3),
            KeyDef("<", UInt16(kVK_LeftArrow)),
            KeyDef(">", UInt16(kVK_RightArrow)),
        ],
    ]

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: spacing) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                        keyView(key)
                    }
                }
            }
        }
    }

    private func keyView(_ key: KeyDef) -> some View {
        let count = keyFrequency[key.keyCode] ?? 0
        let intensity = maxCount > 0 ? Double(count) / Double(maxCount) : 0

        return Text(key.label)
            .font(.system(size: 7, weight: .medium))
            .frame(
                width: keySize * key.width + spacing * (key.width - 1),
                height: keySize
            )
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(heatColor(intensity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
            )
            .help(count > 0 ? "\(KeyCodeMap.name(for: key.keyCode)): \(count)" : KeyCodeMap.name(for: key.keyCode))
    }

    private func heatColor(_ intensity: Double) -> Color {
        if intensity == 0 {
            return Color.primary.opacity(0.05)
        }
        let clamped = min(max(intensity, 0), 1)
        return Color.orange.opacity(0.15 + clamped * 0.7)
    }
}
