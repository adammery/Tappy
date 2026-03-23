import SwiftUI

struct MouseStatsView: View {
    let mouse: MouseStats

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Mouse", systemImage: "computermouse")
                .font(.headline)

            StatRow(label: "Total Clicks", value: mouse.totalClicks.compact)

            MouseHeatmapView(
                leftClicks: mouse.leftClicks,
                rightClicks: mouse.rightClicks,
                middleClicks: mouse.middleClicks
            )
            .padding(.top, 2)
        }
    }
}
