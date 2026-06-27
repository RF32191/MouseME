# MouseMe — Desktop Helper

The iOS app sends mouse / keyboard / media events to this helper, which
injects them as real input on macOS, Windows, or Linux. There are four ways
to connect; pick whichever suits your setup.

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install pyautogui zeroconf qrcode bleak
```

## Connection modes

### 1. Default — phone joins helper's Wi-Fi (recommended)
```bash
python3 mouseme_server.py
```
The server advertises `_mouseme._tcp` over Bonjour and prints a pairing
URL + ASCII QR. From the Connect tab pick the Bonjour entry, scan the QR,
or type the LAN IP manually.

### 2. Hotspot host — phone is the network
The phone runs the listener. Useful when there's no Wi-Fi router and you
turn on Personal Hotspot.

1. In the app, **Connect → Host on this phone → Start host on this phone**.
2. Turn on Personal Hotspot in iOS Settings and join it from your computer.
3. On the computer:
   ```bash
   python3 mouseme_server.py --host
   ```
   The helper auto-discovers the phone over Bonjour (`_mousemehost._tcp`).
   Or dial directly:
   ```bash
   python3 mouseme_server.py --connect 172.20.10.1:8237
   ```

### 3. Bluetooth LE — no Wi-Fi at all
```bash
python3 mouseme_server.py --bluetooth
```
Scans for the MouseMe BLE service, connects, and receives events through
notifications. In the app, tap **Connect → Pair via Bluetooth**. Throughput
is lower than Wi-Fi but works completely off-grid.

## Platform notes

* **macOS** — grant the terminal (or the Python binary) **Accessibility**
  permission in *System Settings → Privacy & Security → Accessibility* the
  first time you run it, or `pyautogui` calls will silently no-op. For
  Bluetooth mode also grant Bluetooth permission to your terminal.
* **Linux** — needs an X11 session; under Wayland install `python-xlib` and
  switch to an X session, or use the `pynput` backend instead.
* **Windows** — no extra setup required. Brightness keys aren't sent
  (use Fn keys directly).

## Wire protocol

Newline-delimited JSON, both directions. Phone → helper:

```json
{"t":"hello","name":"Ryan's iPhone","style":"trackpad"}
{"t":"move","dx":1.4,"dy":-0.6}
{"t":"click","button":"left","action":"click"}
{"t":"scroll","dx":0,"dy":3}
{"t":"key","key":"c","mods":["cmd"]}
{"t":"text","text":"hello"}
{"t":"media","cmd":"volume_up"}
{"t":"jiggle"}
{"t":"ping","id":42,"ts":1718800000000}
```

Helper → phone (TCP modes only; BLE is one-way notify):

```json
{"t":"pong","id":42}
```

