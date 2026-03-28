import SwiftUI

struct MenuBarView: View {
    var stats: StatsManager
    var permission: PermissionManager
    var updateChecker: UpdateChecker
    var onStart: () -> Void
    var onLive: ((Bool) -> Void)?
    @State private var showOptions = false
    @State private var showAllApps = false
    @State private var selectedTab = 0
    @State private var historySnapshot: [String: DailySnapshot] = [:]
    @State private var showResetAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !permission.hasPermission {
                permissionView
            } else {
                HStack(spacing: 0) {
                    tabButton("Session", tag: 0)
                    tabButton("All Time", tag: 1)
                    tabButton("Activity", tag: 2)
                }
                .background(RoundedRectangle(cornerRadius: 6).fill(.primary.opacity(0.06)))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                if selectedTab <= 1 {
                    totalView
                    Divider()
                    keyboardSection
                    if !currentTopApps.isEmpty {
                        Divider()
                        perAppSection
                    }
                    Divider()
                    mouseSection
                    Divider()
                    uptimeSection
                } else if selectedTab == 2 {
                    ActivityView(history: historySnapshot)
                }

                Divider()
                footerView
            }
        }
        .padding(12)
        .frame(width: permission.hasPermission ? 310 : 220)
        .task {
            permission.checkPermission()
            if permission.hasPermission {
                onStart()
                onLive?(true)
            }
        }
        .onAppear {
            onLive?(true)
            stats.syncTodayToHistory()
            historySnapshot = stats.dailyHistory
        }
        .onDisappear { onLive?(false) }
        .onChange(of: selectedTab) { _, tab in
            onLive?(tab != 2)
        }
        .alert("Reset All Data?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                stats.resetStats()
            }
        } message: {
            Text("This will permanently delete all stats, history, and session data.")
        }
    }

    private var totalView: some View {
        let kb = currentKeyboard
        let ms = currentMouse
        let total = kb.totalKeystrokes + ms.totalClicks
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text(total.compact)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(isSession ? "Session Inputs" : "Total Inputs")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 14) {
                VStack(spacing: 2) {
                    Image(systemName: "keyboard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(kb.totalKeystrokes.compact)
                        .font(.callout.weight(.semibold))
                        .fontDesign(.monospaced)
                }
                VStack(spacing: 2) {
                    Image(systemName: "computermouse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ms.totalClicks.compact)
                        .font(.callout.weight(.semibold))
                        .fontDesign(.monospaced)
                }
            }
        }
    }

    private var keyboardSection: some View {
        let kb = currentKeyboard
        return VStack(alignment: .leading, spacing: 6) {
            Label("Keyboard", systemImage: "keyboard")
                .font(.headline)
            StatRow(label: "Keystrokes", value: kb.totalKeystrokes.compact)
            StatRow(label: "Speed", value: "\(Int(kb.typingSpeed)) keys/min")
            KeyboardHeatmapView(keyFrequency: kb.keyFrequency)
                .padding(.top, 2)
        }
    }

    private var mouseSection: some View {
        let ms = currentMouse
        return VStack(alignment: .leading, spacing: 6) {
            Label("Mouse", systemImage: "computermouse")
                .font(.headline)
            StatRow(label: "Total Clicks", value: ms.totalClicks.compact)
            MouseHeatmapView(
                leftClicks: ms.leftClicks,
                rightClicks: ms.rightClicks,
                middleClicks: ms.middleClicks
            )
            .padding(.top, 2)
        }
    }

    private var perAppSection: some View {
        let top5 = currentTopApps
        let perAppData = isSession ? stats.sessionPerApp : stats.perApp
        let maxInputs = top5.first?.stats.totalInputs ?? 1
        let totalAll = perAppData.values.reduce(0) { $0 + $1.totalInputs }

        return VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showAllApps.toggle()
                }
            } label: {
                HStack {
                    Label("Apps", systemImage: "square.grid.2x2")
                        .font(.headline)
                    Spacer()
                    Image(systemName: showAllApps ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.borderless)

            // Always show #1
            if let first = top5.first {
                appRow(index: 1, name: first.name, inputs: first.stats.totalInputs, maxInputs: maxInputs, totalAll: totalAll)
            }

            // Expanded: show #2-5
            if showAllApps {
                ForEach(Array(top5.dropFirst().enumerated()), id: \.element.name) { i, entry in
                    appRow(index: i + 2, name: entry.name, inputs: entry.stats.totalInputs, maxInputs: maxInputs, totalAll: totalAll)
                }
            }
        }
    }

    private static let barWidth: CGFloat = 80

    private func appRow(index: Int, name: String, inputs: Int, maxInputs: Int, totalAll: Int) -> some View {
        let pct = totalAll > 0 ? Double(inputs) / Double(totalAll) * 100 : 0
        let ratio = CGFloat(inputs) / CGFloat(max(maxInputs, 1))
        return HStack(spacing: 6) {
            Text("\(index).")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .trailing)
            Text(name)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 70, alignment: .leading)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: Self.barWidth, height: 10)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.orange.opacity(0.3 + ratio * 0.5))
                    .frame(width: Self.barWidth * ratio, height: 10)
            }
            Text(inputs.compact)
                .font(.caption2)
                .fontDesign(.monospaced)
                .frame(width: 42, alignment: .trailing)
            Text(String(format: "%.0f%%", pct))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private var uptimeSection: some View {
        StatRow(label: "Active", value: isSession ? stats.sessionActiveTimeFormatted : stats.totalActiveTimeFormatted)
    }

    private var permissionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("Input Monitoring")
                .font(.headline)

            Text("Allow Tappy to count your inputs.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Grant Access") {
                permission.requestPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            Button("System Settings") {
                permission.openSystemSettings()
            }
            .buttonStyle(.borderless)
            .font(.caption)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var footerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showOptions {
                optionsView
            }

            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showOptions.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                        Text("Options")
                    }
                }
                .buttonStyle(.borderless)

                Spacer()

                Text("v\(UpdateChecker.currentVersion)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Button("Quit") {
                    stats.save()
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
            }
            .font(.caption)
        }
    }

    private var optionsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Check for update
            Button {
                Task {
                    await updateChecker.check()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    if updateChecker.isChecking {
                        Text("Checking...")
                    } else if updateChecker.hasChecked {
                        if updateChecker.updateAvailable {
                            Text("v\(updateChecker.latestVersion ?? "?") available")
                                .foregroundStyle(.orange)
                        } else {
                            Text("Up to date")
                                .foregroundStyle(.green)
                        }
                    } else {
                        Text("Check for Update")
                    }
                }
            }
            .buttonStyle(.borderless)

            if updateChecker.updateAvailable, let urlString = updateChecker.updateURL,
               let url = URL(string: urlString) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle")
                        Text("Download v\(updateChecker.latestVersion ?? "?")")
                    }
                    .foregroundStyle(.orange)
                }
                .buttonStyle(.borderless)
            }

            Divider()

            // Export
            Button {
                stats.exportStats()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Data")
                }
            }
            .buttonStyle(.borderless)

            // Import
            Button {
                stats.importStats()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Import Data")
                }
            }
            .buttonStyle(.borderless)

            Divider()

            // Reset Session
            Button {
                stats.resetSession()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset Session")
                }
            }
            .buttonStyle(.borderless)

            // Reset All
            Button {
                showResetAlert = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text("Reset All Data")
                }
                .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .font(.caption)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.primary.opacity(0.04))
        )
    }

    private var isSession: Bool { selectedTab == 0 }

    private var currentKeyboard: KeyboardStats {
        isSession ? stats.sessionKeyboard : stats.keyboard
    }

    private var currentMouse: MouseStats {
        isSession ? stats.sessionMouse : stats.mouse
    }

    private var currentTopApps: [(name: String, stats: AppStats)] {
        isSession ? stats.sessionTopApps : stats.topApps
    }

    private func tabButton(_ title: String, tag: Int) -> some View {
        Button {
            selectedTab = tag
        } label: {
            Text(title)
                .font(.caption.weight(selectedTab == tag ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(
                    selectedTab == tag
                        ? RoundedRectangle(cornerRadius: 5).fill(Color.orange.opacity(0.8))
                        : RoundedRectangle(cornerRadius: 5).fill(Color.clear)
                )
                .foregroundStyle(selectedTab == tag ? .white : .secondary)
        }
        .buttonStyle(.borderless)
    }
}
