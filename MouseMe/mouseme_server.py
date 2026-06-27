#!/usr/bin/env python3
"""
MouseMe desktop helper.

Receives JSON-lines events from the MouseMe iOS app and injects them as real
mouse / keyboard / media input on the host computer.

Four ways to connect:

  1. Default — helper listens on TCP and advertises Bonjour. Phone dials in.
        python3 mouseme_server.py

  2. Hotspot host — helper auto-discovers the phone (running "Host on this
     phone") over Bonjour and dials in.
        python3 mouseme_server.py --host

  3. Reverse / manual — dial a specific phone IP and port (use when the
     phone runs Personal Hotspot and you joined its network).
        python3 mouseme_server.py --connect 172.20.10.1:8237

  4. Bluetooth LE — scan for the MouseMe GATT service and subscribe to
     notifications. No Wi-Fi at all.
        python3 mouseme_server.py --bluetooth

  pip install pyautogui zeroconf qrcode bleak
"""
from __future__ import annotations

import argparse
import asyncio
import json
import socket
import socketserver
import sys
import threading
import time
from typing import Optional

import pyautogui

# Optional imports — only required for some modes.
try:
    from zeroconf import IPVersion, ServiceBrowser, ServiceInfo, ServiceListener, Zeroconf
except ImportError:  # pragma: no cover
    Zeroconf = None  # type: ignore

try:
    import qrcode
except ImportError:  # pragma: no cover
    qrcode = None

try:
    from bleak import BleakClient, BleakScanner
except ImportError:  # pragma: no cover
    BleakClient = None  # type: ignore
    BleakScanner = None  # type: ignore

HOST = "0.0.0.0"
PORT = 8237
SERVICE_TYPE_HELPER = "_mouseme._tcp.local."
SERVICE_TYPE_PHONE  = "_mousemehost._tcp.local."

BLE_SERVICE_UUID = "7c2e0001-5a0e-4f4d-9f9c-7a2d5e1a1b01"
BLE_CHAR_UUID    = "7c2e0002-5a0e-4f4d-9f9c-7a2d5e1a1b02"

pyautogui.FAILSAFE = False
pyautogui.MINIMUM_DURATION = 0
pyautogui.MINIMUM_SLEEP = 0
pyautogui.PAUSE = 0

IS_MAC   = sys.platform == "darwin"
IS_WIN   = sys.platform.startswith("win")

# -------- Key / media mapping ----------------------------------------------

def _platform_mods(mods):
    """Translate logical mods (cmd/ctrl/alt/shift) to platform actuals."""
    out = []
    for m in mods or []:
        m = m.lower()
        if m == "cmd":
            out.append("command" if IS_MAC else "ctrl")
        elif m == "alt":
            out.append("option" if IS_MAC else "alt")
        elif m == "win":
            out.append("winleft" if IS_WIN else "command" if IS_MAC else "ctrl")
        else:
            out.append(m)   # ctrl, shift, etc.
    return out

_MEDIA_MAP = {
    "volume_up":      "volumeup",
    "volume_down":    "volumedown",
    "mute":           "volumemute",
    "play_pause":     "playpause",
    "next":           "nexttrack",
    "prev":           "prevtrack",
}

def _media_key(cmd: str) -> Optional[str]:
    if cmd in _MEDIA_MAP:
        return _MEDIA_MAP[cmd]
    if cmd == "brightness_up":
        return "f2" if IS_MAC else None
    if cmd == "brightness_down":
        return "f1" if IS_MAC else None
    return None

# -------- Event handler -----------------------------------------------------

def handle_event(evt: dict, reply=None) -> None:
    """Apply one event. `reply(dict)` is an optional sender for pong/etc."""
    t = evt.get("t")

    if t == "move":
        dx = float(evt.get("dx", 0))
        dy = float(evt.get("dy", 0))
        if dx or dy:
            pyautogui.moveRel(dx, dy, duration=0, _pause=False)

    elif t == "click":
        btn = evt.get("button", "left")
        act = evt.get("action", "click")
        if act == "down":
            pyautogui.mouseDown(button=btn, _pause=False)
        elif act == "up":
            pyautogui.mouseUp(button=btn, _pause=False)
        else:
            pyautogui.click(button=btn, _pause=False)

    elif t == "scroll":
        dy = float(evt.get("dy", 0))
        if dy:
            pyautogui.scroll(int(dy), _pause=False)

    elif t == "key":
        key = evt.get("key")
        if not key:
            return
        mods = _platform_mods(evt.get("mods") or [])
        if mods:
            pyautogui.hotkey(*mods, key, _pause=False)
        else:
            pyautogui.press(key, _pause=False)

    elif t == "text":
        s = evt.get("text") or ""
        if s:
            pyautogui.write(s, interval=0, _pause=False)

    elif t == "media":
        cmd = evt.get("cmd") or ""
        mapped = _media_key(cmd)
        if mapped:
            pyautogui.press(mapped, _pause=False)

    elif t == "jiggle":
        # Move the cursor in a small square so the user can find it on screen.
        for dx, dy in [(40,0),(-80,0),(80,0),(-40,0),(0,40),(0,-80),(0,80),(0,-40)]:
            pyautogui.moveRel(dx, dy, duration=0, _pause=False)
            time.sleep(0.02)

    elif t == "ping":
        if reply is not None:
            pid = evt.get("id")
            reply({"t": "pong", "id": pid})

    elif t == "hello":
        print(f"[hello] {evt.get('name', '?')} (style={evt.get('style')})")

# -------- Line-framed feeder for any byte stream ----------------------------

class LineFeeder:
    """Accumulates bytes, splits on 0x0A, decodes JSON, calls handle_event."""
    def __init__(self, reply=None):
        self.buf = bytearray()
        self.reply = reply

    def feed(self, chunk: bytes):
        self.buf.extend(chunk)
        while True:
            try:
                idx = self.buf.index(0x0A)
            except ValueError:
                return
            line = bytes(self.buf[:idx]).strip()
            del self.buf[:idx + 1]
            if not line:
                continue
            try:
                evt = json.loads(line)
            except json.JSONDecodeError:
                continue
            handle_event(evt, reply=self.reply)

# -------- Mode 1: helper listens (default) ----------------------------------

class LineHandler(socketserver.StreamRequestHandler):
    def handle(self) -> None:
        peer = self.client_address
        print(f"[connect] {peer}")
        lock = threading.Lock()

        def reply(obj):
            try:
                with lock:
                    self.wfile.write((json.dumps(obj) + "\n").encode())
                    self.wfile.flush()
            except OSError:
                pass

        feeder = LineFeeder(reply=reply)
        try:
            while True:
                data = self.request.recv(64 * 1024)
                if not data:
                    break
                feeder.feed(data)
        except (ConnectionResetError, BrokenPipeError):
            pass
        finally:
            print(f"[disconnect] {peer}")


class ThreadedServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    daemon_threads = True
    allow_reuse_address = True

def _local_ip() -> str:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


def register_helper_bonjour(zc: "Zeroconf", port: int) -> "ServiceInfo":
    hostname = socket.gethostname().split(".")[0]
    name = f"{hostname}.{SERVICE_TYPE_HELPER}"
    info = ServiceInfo(
        SERVICE_TYPE_HELPER,
        name,
        addresses=[socket.inet_aton(_local_ip())],
        port=port,
        properties={"v": "1"},
        server=f"{hostname}.local.",
    )
    zc.register_service(info)
    return info


def run_listen(port: int, no_qr: bool):
    if Zeroconf is None:
        print("zeroconf not installed — running without Bonjour. `pip install zeroconf`")
        zc = None
        info = None
    else:
        zc = Zeroconf()
        info = register_helper_bonjour(zc, port)

    server = ThreadedServer((HOST, port), LineHandler)
    try:
        ip = _local_ip()
        hostname = socket.gethostname().split(".")[0]
        url = f"mouseme://connect?host={ip}&port={port}&name={hostname}"
        print(f"MouseMe helper listening on {ip}:{port}")
        if zc is not None:
            print(f"Bonjour: {SERVICE_TYPE_HELPER}")
        print(f"Pairing URL: {url}")
        if qrcode is not None and not no_qr:
            qr = qrcode.QRCode(border=1)
            qr.add_data(url)
            qr.make(fit=True)
            print()
            qr.print_ascii(invert=True)
            print("Scan from the MouseMe app's Connect tab.")
        print("Press Ctrl+C to stop.")
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        if zc and info:
            zc.unregister_service(info)
            zc.close()
        server.shutdown()
        server.server_close()

# -------- Mode 2 & 3: helper dials phone ------------------------------------

def _connect_to_phone(host: str, port: int):
    print(f"[dial] connecting to phone at {host}:{port}…")
    s = socket.create_connection((host, port), timeout=10)
    s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    print(f"[connected] {host}:{port}")

    lock = threading.Lock()
    def reply(obj):
        try:
            with lock:
                s.sendall((json.dumps(obj) + "\n").encode())
        except OSError:
            pass

    feeder = LineFeeder(reply=reply)
    try:
        while True:
            data = s.recv(64 * 1024)
            if not data:
                break
            feeder.feed(data)
    except (ConnectionResetError, BrokenPipeError, OSError):
        pass
    finally:
        s.close()
        print(f"[disconnect] {host}:{port}")


class _PhoneFinder(ServiceListener):
    def __init__(self):
        self.found = threading.Event()
        self.endpoint = None  # (ip, port, name)

    def add_service(self, zc, type_, name):
        info = zc.get_service_info(type_, name)
        if not info or not info.addresses:
            return
        ip = socket.inet_ntoa(info.addresses[0])
        self.endpoint = (ip, info.port, name)
        self.found.set()

    def update_service(self, *a, **kw):
        pass

    def remove_service(self, *a, **kw):
        pass


def run_host_discover():
    if Zeroconf is None:
        print("zeroconf required: pip install zeroconf"); return
    zc = Zeroconf()
    finder = _PhoneFinder()
    print(f"Looking for a phone advertising {SERVICE_TYPE_PHONE} …")
    ServiceBrowser(zc, SERVICE_TYPE_PHONE, finder)
    try:
        if not finder.found.wait(timeout=30):
            print("Timed out — make sure the phone is on the same network and 'Start host on this phone' is on.")
            return
        ip, port, name = finder.endpoint  # type: ignore
        print(f"Found phone: {name} @ {ip}:{port}")
        while True:
            try:
                _connect_to_phone(ip, port)
            except OSError as e:
                print(f"[reconnect] {e}")
            time.sleep(2)
    except KeyboardInterrupt:
        pass
    finally:
        zc.close()


def run_connect(target: str):
    host, _, p = target.partition(":")
    port = int(p) if p else PORT
    while True:
        try:
            _connect_to_phone(host, port)
        except OSError as e:
            print(f"[reconnect] {e}")
        try:
            time.sleep(2)
        except KeyboardInterrupt:
            return

# -------- Mode 4: Bluetooth LE ----------------------------------------------

async def _ble_main(name_filter: Optional[str]):
    if BleakScanner is None or BleakClient is None:
        print("bleak required: pip install bleak"); return
    while True:
        print("[ble] scanning for MouseMe service…")
        device = None
        try:
            device = await BleakScanner.find_device_by_filter(
                lambda d, ad: BLE_SERVICE_UUID in [str(u).lower() for u in (ad.service_uuids or [])]
                              and (name_filter is None or (d.name or "").startswith(name_filter)),
                timeout=15.0,
            )
        except Exception as e:  # pragma: no cover
            print(f"[ble] scan error: {e}")
        if device is None:
            print("[ble] no phone found, retrying…")
            await asyncio.sleep(3)
            continue

        print(f"[ble] connecting to {device.name or device.address}")
        feeder = LineFeeder(reply=None)  # BLE is one-way

        def on_notify(_, data: bytearray):
            feeder.feed(bytes(data))

        try:
            async with BleakClient(device) as client:
                await client.start_notify(BLE_CHAR_UUID, on_notify)
                print("[ble] subscribed — receiving events. Ctrl+C to quit.")
                while client.is_connected:
                    await asyncio.sleep(0.5)
                print("[ble] disconnected")
        except Exception as e:
            print(f"[ble] connection error: {e}")
        await asyncio.sleep(2)


def run_bluetooth(name_filter: Optional[str]):
    try:
        asyncio.run(_ble_main(name_filter))
    except KeyboardInterrupt:
        pass

# -------- Entrypoint --------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description="MouseMe helper")
    ap.add_argument("--port", type=int, default=PORT,
                    help="TCP listen port for default mode (default 8237)")
    ap.add_argument("--no-qr", action="store_true", help="don't print the pairing QR")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--host", action="store_true",
                   help="auto-discover and dial a phone running 'Host on this phone'")
    g.add_argument("--connect", metavar="HOST:PORT",
                   help="dial a phone host directly (use with Personal Hotspot)")
    g.add_argument("--bluetooth", action="store_true",
                   help="receive events over Bluetooth LE (no Wi-Fi)")
    ap.add_argument("--ble-name", default=None,
                    help="only connect to BLE peripherals whose name starts with this")
    args = ap.parse_args()

    if args.bluetooth:
        run_bluetooth(args.ble_name)
    elif args.host:
        run_host_discover()
    elif args.connect:
        run_connect(args.connect)
    else:
        run_listen(args.port, args.no_qr)


if __name__ == "__main__":
    main()
