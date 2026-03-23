import SwiftUI

struct UptimeView: View {
    let systemUptime: String
    let sessionDuration: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Uptime", systemImage: "clock")
                .font(.headline)

            StatRow(label: "System", value: systemUptime)
            StatRow(label: "Session", value: sessionDuration)
        }
    }
}
