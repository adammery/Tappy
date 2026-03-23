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

```bash
git clone https://github.com/adammery/Tappy.git
cd Tappy
bash scripts/bundle.sh
open build/Tappy.app
```

Requires macOS 14+ and Swift 6.

## License

[MIT](LICENSE)
