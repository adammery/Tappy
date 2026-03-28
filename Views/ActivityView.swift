import SwiftUI

enum ActivityFilter: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

struct ActivityView: View {
    let history: [String: DailySnapshot]
    @State private var filter: ActivityFilter = .daily
    @State private var selectedIndex: Int?

    private struct BarData {
        var label: String
        var keys: Int = 0
        var clicks: Int = 0
        var active: Int = 0
        var keyFrequency: [UInt16: Int] = [:]
        var leftClicks: Int = 0
        var rightClicks: Int = 0
        var middleClicks: Int = 0
        var perApp: [String: AppStats] = [:]

        mutating func merge(_ snap: DailySnapshot) {
            keys += snap.keystrokes
            clicks += snap.clicks
            active += snap.activeSeconds
            leftClicks += snap.leftClicks
            rightClicks += snap.rightClicks
            middleClicks += snap.middleClicks
            for (k, v) in snap.keyFrequency {
                keyFrequency[k, default: 0] += v
            }
            for (app, stats) in snap.perApp {
                perApp[app, default: AppStats()].keystrokes += stats.keystrokes
                perApp[app, default: AppStats()].clicks += stats.clicks
            }
        }
    }

    private var bars: [BarData] {
        let history = history
        let cal = Calendar.current
        let today = Date()

        switch filter {
        case .daily:
            return (0..<7).reversed().map { offset in
                let date = cal.date(byAdding: .day, value: -offset, to: today)!
                let key = Self.dayFormatter.string(from: date)
                var bar = BarData(label: Self.shortDayFormatter.string(from: date))
                if let snap = history[key] { bar.merge(snap) }
                return bar
            }
        case .weekly:
            return (0..<4).reversed().map { week in
                let weekEnd = cal.date(byAdding: .day, value: -week * 7, to: today)!
                let weekStart = cal.date(byAdding: .day, value: -6, to: weekEnd)!
                var bar = BarData(label: "W\(4 - week)")
                for d in 0..<7 {
                    let date = cal.date(byAdding: .day, value: d, to: weekStart)!
                    let key = Self.dayFormatter.string(from: date)
                    if let snap = history[key] { bar.merge(snap) }
                }
                return bar
            }
        case .monthly:
            return (0..<6).reversed().map { offset in
                let month = cal.date(byAdding: .month, value: -offset, to: today)!
                let range = cal.range(of: .day, in: .month, for: month)!
                let comps = cal.dateComponents([.year, .month], from: month)
                var bar = BarData(label: Self.shortMonthFormatter.string(from: month))
                for day in range {
                    let key = String(format: "%04d-%02d-%02d", comps.year!, comps.month!, day)
                    if let snap = history[key] { bar.merge(snap) }
                }
                return bar
            }
        }
    }

    /// Data for display — either selected bar or full period aggregate
    private var displayData: BarData {
        let allBars = bars
        if let idx = selectedIndex, allBars.indices.contains(idx) {
            return allBars[idx]
        }
        return allBars.reduce(into: BarData(label: "")) { result, bar in
            result.keys += bar.keys
            result.clicks += bar.clicks
            result.active += bar.active
            result.leftClicks += bar.leftClicks
            result.rightClicks += bar.rightClicks
            result.middleClicks += bar.middleClicks
            for (k, v) in bar.keyFrequency {
                result.keyFrequency[k, default: 0] += v
            }
            for (app, stats) in bar.perApp {
                result.perApp[app, default: AppStats()].keystrokes += stats.keystrokes
                result.perApp[app, default: AppStats()].clicks += stats.clicks
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                ForEach(ActivityFilter.allCases, id: \.self) { f in
                    Button {
                        filter = f
                        selectedIndex = nil
                    } label: {
                        Text(f.rawValue)
                            .font(.caption.weight(filter == f ? .semibold : .regular))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                            .background(
                                filter == f
                                    ? RoundedRectangle(cornerRadius: 5).fill(Color.orange.opacity(0.8))
                                    : RoundedRectangle(cornerRadius: 5).fill(Color.clear)
                            )
                            .foregroundStyle(filter == f ? .white : .secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(.primary.opacity(0.06)))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            chartView

            summaryView

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Label("Keyboard", systemImage: "keyboard")
                    .font(.headline)
                KeyboardHeatmapView(keyFrequency: displayData.keyFrequency)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Label("Mouse", systemImage: "computermouse")
                    .font(.headline)
                MouseHeatmapView(
                    leftClicks: displayData.leftClicks,
                    rightClicks: displayData.rightClicks,
                    middleClicks: displayData.middleClicks
                )
            }

            if !displayData.perApp.isEmpty {
                Divider()
                appsSection
            }
        }
    }

    private var chartView: some View {
        let data = bars
        let maxVal = data.map { $0.keys + $0.clicks }.max() ?? 1

        return VStack(spacing: 4) {
            ZStack {
                Canvas { context, size in
                    let barCount = CGFloat(data.count)
                    let spacing: CGFloat = 4
                    let barWidth = (size.width - spacing * (barCount - 1)) / barCount
                    let maxHeight = size.height

                    for (i, bar) in data.enumerated() {
                        let total = bar.keys + bar.clicks
                        let ratio = maxVal > 0 ? CGFloat(total) / CGFloat(maxVal) : 0
                        let height = maxHeight * ratio
                        let x = CGFloat(i) * (barWidth + spacing)
                        let y = maxHeight - height
                        let isSelected = selectedIndex == i

                        let rect = CGRect(x: x, y: y, width: barWidth, height: height)
                        let path = Path(roundedRect: rect, cornerRadius: 3)
                        let opacity = isSelected ? 0.9 : (0.3 + ratio * 0.5)
                        context.fill(path, with: .color(.orange.opacity(opacity)))

                        // Clicks portion at bottom
                        if bar.clicks > 0 && total > 0 {
                            let clickRatio = CGFloat(bar.clicks) / CGFloat(total)
                            let clickHeight = height * clickRatio
                            let clickRect = CGRect(x: x, y: maxHeight - clickHeight, width: barWidth, height: clickHeight)
                            let clickPath = Path(roundedRect: clickRect, cornerRadius: 2)
                            context.fill(clickPath, with: .color(.blue.opacity(isSelected ? 0.4 : 0.25)))
                        }

                        // Selection indicator — dot under bar
                        if isSelected {
                            let dotSize: CGFloat = 4
                            let dotRect = CGRect(x: x + barWidth / 2 - dotSize / 2, y: maxHeight - dotSize - 1, width: dotSize, height: dotSize)
                            context.fill(Path(ellipseIn: dotRect), with: .color(.orange))
                        }
                    }
                }
                .frame(height: 80)

                // Tap targets
                HStack(spacing: 4) {
                    ForEach(0..<data.count, id: \.self) { i in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedIndex = selectedIndex == i ? nil : i
                                }
                            }
                    }
                }
                .frame(height: 80)
            }

            // Labels
            HStack(spacing: 0) {
                ForEach(Array(data.enumerated()), id: \.offset) { i, bar in
                    Text(bar.label)
                        .font(.system(size: 8, weight: selectedIndex == i ? .bold : .regular))
                        .foregroundStyle(selectedIndex == i ? .orange : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var summaryView: some View {
        let p = displayData
        let totalInputs = p.keys + p.clicks

        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                statBlock(icon: "hand.tap", value: totalInputs.compact, label: "Inputs")
                statBlock(icon: "keyboard", value: p.keys.compact, label: "Keys")
                statBlock(icon: "computermouse", value: p.clicks.compact, label: "Clicks")
            }

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text(formatSeconds(p.active))
                    .font(.callout.weight(.semibold))
                    .fontDesign(.monospaced)
                Text("Active")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.primary.opacity(0.08))
            )
        }
    }

    private var appsSection: some View {
        let sorted = displayData.perApp.sorted { $0.value.totalInputs > $1.value.totalInputs }.prefix(5)
        let maxInputs = sorted.first?.value.totalInputs ?? 1
        let totalAll = displayData.perApp.values.reduce(0) { $0 + $1.totalInputs }

        return VStack(alignment: .leading, spacing: 4) {
            Label("Apps", systemImage: "square.grid.2x2")
                .font(.headline)
            ForEach(Array(sorted.enumerated()), id: \.element.key) { i, entry in
                let pct = totalAll > 0 ? Double(entry.value.totalInputs) / Double(totalAll) * 100 : 0
                let ratio = CGFloat(entry.value.totalInputs) / CGFloat(max(maxInputs, 1))
                HStack(spacing: 5) {
                    Text("\(i + 1).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 14, alignment: .trailing)
                    Text(entry.key)
                        .font(.caption2)
                        .lineLimit(1)
                        .frame(width: 60, alignment: .leading)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.primary.opacity(0.05))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.orange.opacity(0.3 + ratio * 0.5))
                            .frame(width: max(ratio * 80, 0), height: 8)
                    }
                    .frame(width: 80)
                    Text(entry.value.totalInputs.compact)
                        .font(.caption2)
                        .fontDesign(.monospaced)
                        .frame(width: 36, alignment: .trailing)
                    Text(String(format: "%.0f%%", pct))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
    }

    private func statBlock(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.orange)
            Text(value)
                .font(.callout.weight(.semibold))
                .fontDesign(.monospaced)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.primary.opacity(0.08))
        )
    }

    private func formatSeconds(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    // MARK: - Formatters

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    private static let shortMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()
}
