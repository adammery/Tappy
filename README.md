# Tappy

A lightweight macOS menu bar app that tracks your keyboard and mouse activity — keystrokes, clicks, typing speed, and a keyboard heatmap.

---

## ⚠️ macOS Installation Note

Tappy is open-source and not signed with an Apple Developer ID.
Because of this, macOS may say the app is **damaged** when opening it for the first time. This is expected and does **not** mean the app is unsafe.

Fix in 5 seconds:

```bash
xattr -cr /Applications/Tappy.app
```

Alternatively:
Right-click **Tappy.app** → **Open** → **Open**

---

## 🚀 Quick Start

1. Download the latest `.dmg` from [Releases](https://github.com/adammery/Tappy/releases)
2. Open the DMG and drag **Tappy** to **Applications**
3. Run:

```bash
xattr -cr /Applications/Tappy.app
```

4. Launch Tappy
5. Grant **Input Monitoring** permission when prompted
   *(System Settings → Privacy & Security → Input Monitoring)*
6. Restart Tappy

Requires **macOS 14+**

---

## Features

* **Keyboard tracking** — total keystrokes, typing speed (keys/min), keyboard heatmap
* **Mouse tracking** — total clicks with left/right/middle breakdown
* **System uptime** — system and session duration
* **Export / Import** — encrypted backup file (`.itbackup`) for transferring data between devices
* **Check for updates** — checks GitHub releases for new versions

---

## Privacy

All data is stored **locally on your Mac** using UserDefaults.

Tappy:

* has **no analytics**
* has **no telemetry**
* sends **no usage data**
* does **not** track or upload personal information

The only outbound request is the optional **Check for Updates**, which queries the GitHub API.

Tappy uses macOS **Input Monitoring** permission only to count activity events.

* It does **not** record what you type
* It does **not** capture text or passwords
* It only counts that a key or mouse button was pressed

---

## License

[MIT](LICENSE)
