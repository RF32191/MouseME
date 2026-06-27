# MouseME

Turn your iPhone into a wireless mouse for your Mac or PC.

## How it works

MouseME has two components:

| Component | Location | Language |
|-----------|----------|----------|
| **iOS App** | `ios/` | Swift / SwiftUI |
| **Server** | `server/` | Python |

The iPhone app captures touch gestures and streams movement / click / scroll
events over a **WebSocket** to a small Python server running on the host
computer.  The server translates those events into real mouse actions using
[PyAutoGUI](https://pyautogui.readthedocs.io).

```
iPhone (iOS App)  ──WebSocket──▶  Mac/PC (server.py)  ──▶  System cursor
```

---

## Requirements

### Server (host computer)
- Python 3.10 or later
- macOS, Linux, or Windows

### iOS App
- Xcode 15 or later
- iOS 16 or later
- iPhone and host computer on the **same local network**

---

## Setup

### 1 — Start the server on your computer

```bash
cd server
pip install -r requirements.txt
python server.py          # listens on port 8765 by default
python server.py 9000     # or specify a custom port
```

Find your computer's local IP address:
- **macOS**: `ipconfig getifaddr en0`
- **Linux**: `ip route get 1 | awk '{print $7}'`
- **Windows**: `ipconfig` → look for IPv4 Address

### 2 — Build and run the iOS app

1. Open `ios/MouseME.xcodeproj` in Xcode.
2. Select your iPhone as the run destination.
3. Build & run (`⌘R`).

### 3 — Connect

1. Tap the **⚙ gear** icon in the top-right of the app.
2. Enter the **IP address** and **port** of the computer running the server.
3. Tap **Connect** (or the Wi-Fi icon in the header).

A green Wi-Fi icon confirms a live connection.

---

## Controls

| Gesture / Button | Action |
|------------------|--------|
| **Drag** on trackpad | Move pointer |
| **Tap** on trackpad | Left click |
| **Long press** on trackpad | Right click |
| **Drag** on scroll strip | Scroll up / down |
| **Left Click** button | Left click |
| **Right Click** button | Right click |
| **Double Click** button | Double click |

Adjust pointer speed in **Settings → Sensitivity**.

---

## Server — WebSocket protocol

All messages are JSON objects with an `action` field:

| `action` | Extra fields | Description |
|----------|--------------|-------------|
| `move` | `dx` (float), `dy` (float) | Move pointer by delta pixels |
| `click` | — | Left click |
| `double_click` | — | Double click |
| `right_click` | — | Right click |
| `scroll` | `amount` (float, +up / −down) | Scroll |

---

## Running server tests

```bash
cd server
pip install -r requirements.txt
python -m pytest test_server.py -v
```