import SwiftUI

struct MenuBarView: View {
    var stats: StatsManager
    var permission: PermissionManager
    var updateChecker: UpdateChecker
    var onStart: () -> Void
    var onLive: ((Bool) -> Void)?
    @State private var showOptions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !permission.hasPermission {
                permissionView
            } else {
                totalView
                Divider()
                keyboardSection
                Divider()
                mouseSection
                Divider()
                uptimeSection
                Divider()
                footerView
            }
        }
        .padding(12)
        .frame(width: 310)
        .task {
            permission.checkPermission()
            if permission.hasPermission {
                onStart()
            }
        }
        .onAppear { onLive?(true) }
        .onDisappear { onLive?(false) }
    }

    private var totalView: some View {
        let total = stats.keyboard.totalKeystrokes + stats.mouse.totalClicks
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text(total.compact)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Total Inputs")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 14) {
                VStack(spacing: 2) {
                    Image(systemName: "keyboard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(stats.keyboard.totalKeystrokes.compact)
                        .font(.callout.weight(.semibold))
                        .fontDesign(.monospaced)
                }
                VStack(spacing: 2) {
                    Image(systemName: "computermouse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(stats.mouse.totalClicks.compact)
                        .font(.callout.weight(.semibold))
                        .fontDesign(.monospaced)
                }
            }
        }
    }

    private var keyboardSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Keyboard", systemImage: "keyboard")
                .font(.headline)
            StatRow(label: "Keystrokes", value: stats.keyboard.totalKeystrokes.compact)
            StatRow(label: "Speed", value: "\(Int(stats.keyboard.typingSpeed)) keys/min")
            KeyboardHeatmapView(keyFrequency: stats.keyboard.keyFrequency)
                .padding(.top, 2)
        }
    }

    private var mouseSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Mouse", systemImage: "computermouse")
                .font(.headline)
            StatRow(label: "Total Clicks", value: stats.mouse.totalClicks.compact)
            MouseHeatmapView(
                leftClicks: stats.mouse.leftClicks,
                rightClicks: stats.mouse.rightClicks,
                middleClicks: stats.mouse.middleClicks
            )
            .padding(.top, 2)
        }
    }

    private var uptimeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Uptime", systemImage: "clock")
                .font(.headline)
            StatRow(label: "System", value: stats.systemUptime)
            StatRow(label: "Session", value: stats.sessionDuration)
        }
    }

    private var permissionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("Input Monitoring Required")
                .font(.headline)

            Text("Tappy needs permission to monitor keyboard and mouse events.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Updating? Remove the old Tappy from Input Monitoring, restart and grant access again.")
                .font(.system(size: 9))
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)

            Button("Grant Permission") {
                permission.requestPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            Button("Open System Settings") {
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

            // Reset
            Button {
                stats.resetStats()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text("Reset Stats")
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
}
