# Z Macro — Sailor Piece Boss Macro

A free AutoHotkey v2 macro for **Sailor Piece** (Roblox) that automates boss detection, player count checking, and Discord notifications.

---

## Features

- **Boss Detection** — Scans your screen every 500ms using image recognition. The moment a boss spawns it fires your configured key sequence automatically.
- **Player Count Checker** — Opens the ESC menu on a set interval, scans for Add Friend / Friend buttons to count players. If the server drops below your threshold it plays a recording to reset.
- **Recording Playback** — Plays back InformaalTask `.rec` files automatically when triggered by low player count or manually.
- **Discord Webhook** — Sends a notification with a screenshot to your Discord when a boss spawns so you know even when you're away from your PC.
- **Anti-AFK** — Plays a separate recording on a timer to prevent being kicked.
- **Live Console** — A small terminal window shows real-time logs while the macro is running.
- **Session Logging** — All activity is written to daily log files in `data/logs/`.

---

## Requirements

- [AutoHotkey v2](https://www.autohotkey.com/) — download and install before running
- Windows 10 or 11
- Roblox running in windowed mode

---

## Setup

1. Install **AutoHotkey v2** from [autohotkey.com](https://www.autohotkey.com/)
2. Download the latest release from the [website](https://zmacro.vercel.app) *(link in bio)*
3. Extract the zip anywhere on your PC
4. Double click the `.ahk` file to launch

---

## Configuration

### Boss Detect
- Click **Add Images** and add a cropped screenshot of the boss health bar or name
- Set your key sequence (comma separated e.g. `f,c,c,c,f`)
- Set key delay and scan interval

### Player Count
- Open the ESC menu in Roblox → People tab
- Crop a screenshot of the **Add friend** button and the **Friend** label
- Browse both images in the Player Count tab
- Set your check interval (minutes) and player threshold

### Recording
- Browse your InformaalTask `.rec` file
- Set what happens after playback (resume / wait for players)

### Notify
- Paste your Discord webhook URL
- Paste your Discord User ID for pings
- Enable bloodline stone detection if needed

### Anti-AFK
- Browse a separate `.rec` file for AFK movement
- Set the interval in minutes

---

## Hotkeys

| Key | Action |
|-----|--------|
| F6 | Start / Stop scanning |
| F7 | Reload script |
| F8 | Exit |
| F9 | Stop recording playback |

---

## Is it safe?

This is open source — every line of code is visible in this repository. You can read exactly what it does before running it.

For extra peace of mind you can scan the file yourself at [virustotal.com](https://www.virustotal.com).

---

## Disclaimer

This macro is for educational purposes. Use it responsibly. I am not responsible for any account actions taken by Roblox.

---

## Download

👉 [zmacro.vercel.app](https://zmacro.vercel.app)
