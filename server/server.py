"""
MouseME Server
==============
Runs on the host computer and receives WebSocket events from the MouseME iOS
app, translating them into real mouse actions (move, click, scroll).

Usage:
    pip install -r requirements.txt
    python server.py [PORT]          # default port: 8765
"""

import asyncio
import json
import logging
import sys

import pyautogui
import websockets
import websockets.server

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("mouseme")

# Disable pyautogui's fail-safe corner so accidental moves don't kill the server.
pyautogui.FAILSAFE = False
pyautogui.PAUSE = 0  # Remove the default 0.1 s delay between calls for low latency.

SUPPORTED_ACTIONS = {"move", "click", "double_click", "right_click", "scroll"}


async def handle_client(websocket: websockets.server.ServerConnection) -> None:
    """Handle a single connected iOS client."""
    addr = websocket.remote_address
    log.info("Client connected from %s", addr)
    try:
        async for raw in websocket:
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                log.warning("Ignoring malformed message: %r", raw)
                continue

            action = data.get("action")
            if action not in SUPPORTED_ACTIONS:
                log.debug("Unknown action: %r", action)
                continue

            if action == "move":
                dx = float(data.get("dx", 0))
                dy = float(data.get("dy", 0))
                pyautogui.moveRel(dx, dy, duration=0)

            elif action == "click":
                pyautogui.click()

            elif action == "double_click":
                pyautogui.doubleClick()

            elif action == "right_click":
                pyautogui.rightClick()

            elif action == "scroll":
                # Positive amount scrolls up; negative scrolls down.
                amount = float(data.get("amount", 0))
                pyautogui.scroll(int(amount))

    except websockets.exceptions.ConnectionClosedOK:
        pass
    except websockets.exceptions.ConnectionClosedError as exc:
        log.warning("Client %s disconnected with error: %s", addr, exc)
    finally:
        log.info("Client disconnected: %s", addr)


async def main() -> None:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    log.info("MouseME server listening on 0.0.0.0:%d", port)
    async with websockets.serve(handle_client, "0.0.0.0", port):
        await asyncio.Future()  # Run until interrupted.


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        log.info("Server stopped.")
