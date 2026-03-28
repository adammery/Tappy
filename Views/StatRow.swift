import SwiftUI

private let numberFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.groupingSeparator = ","
    return f
}()

extension Int {
    var compact: String {
        numberFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    var formattedTime: String {
        let h = self / 3600
        let m = (self % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontDesign(.monospaced)
        }
        .font(.callout)
    }
}
