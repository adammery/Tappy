# Tappy

A lightweight macOS menu bar app that tracks your keyboard and mouse activity - keystrokes, clicks, typing speed, and a keyboard heatmap.

## Features

- **Keyboard tracking** - total keystrokes, typing speed (keys/min), keyboard heatmap
- **Mouse tracking** - total clicks with left/right/middle breakdown
- **System uptime** - system and session duration
- **Export / Import** - encrypted backup file (.itbackup) for transferring data between devices
- **Check for updates** - checks GitHub releases for new versions

## Privacy

All data is stored **locally on your Mac** (UserDefaults). Tappy has no network connection, no analytics, no telemetry. The only outbound request is the optional "Check for Update" which hits the GitHub API.

Tappy uses macOS Input Monitoring to count key presses and clicks. It does **not** record what you type — only that a key was pressed.

## Install

1. Download the latest `.dmg` from [Releases](https://github.com/adammery/Tappy/releases)
2. Open the DMG and drag Tappy to Applications
3. Since the app is not signed with an Apple Developer ID, macOS will block it. Right-click Tappy → **Open** → **Open**, or run:
   ```bash
   xattr -cr /Applications/Tappy.app
   ```
4. Grant **Input Monitoring** permission when prompted (System Settings → Privacy & Security → Input Monitoring)

Requires macOS 14+.

## License

[MIT](LICENSE)
