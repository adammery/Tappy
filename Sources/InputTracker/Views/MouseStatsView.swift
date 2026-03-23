import SwiftUI

struct MouseStatsView: View {
    let mouse: MouseStats

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Mouse", systemImage: "computermouse")
                .font(.headline)

            StatRow(label: "Total Clicks", value: mouse.totalClicks.compact)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(mouse.leftClicks.compact)
                        .font(.callout)
                        .fontDesign(.monospaced)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(mouse.rightClicks.compact)
                        .font(.callout)
                        .fontDesign(.monospaced)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Middle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(mouse.middleClicks.compact)
                        .font(.callout)
                        .fontDesign(.monospaced)
                }
            }
            .padding(.leading, 4)
        }
    }
}
