"""Unit tests for the MouseME server (logic that does not need pyautogui)."""

import json
import pathlib
import sys
import unittest
from unittest.mock import MagicMock


def _load_server():
    """Import server.py with pyautogui mocked out so tests run anywhere."""
    import importlib.util

    pyautogui_mock = MagicMock()
    sys.modules["pyautogui"] = pyautogui_mock

    spec = importlib.util.spec_from_file_location(
        "server",
        pathlib.Path(__file__).parent / "server.py",
    )
    mod = importlib.util.module_from_spec(spec)
    mod.pyautogui = pyautogui_mock  # type: ignore[attr-defined]
    spec.loader.exec_module(mod)
    return mod, pyautogui_mock


async def _async_gen(messages):
    """Yield messages one by one as an async generator."""
    for msg in messages:
        yield msg


def _make_ws(messages):
    """Return a mock WebSocket that asynchronously yields *messages*."""
    ws = MagicMock()
    ws.remote_address = ("127.0.0.1", 12345)
    ws.__aiter__ = lambda self: _async_gen(messages)
    return ws


class TestServerActions(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.server_mod, self.pyautogui = _load_server()

    async def _send(self, payload: dict):
        ws = _make_ws([json.dumps(payload)])
        await self.server_mod.handle_client(ws)

    async def test_move_calls_moveRel(self):
        await self._send({"action": "move", "dx": 10, "dy": -5})
        self.pyautogui.moveRel.assert_called_once_with(10.0, -5.0, duration=0)

    async def test_click_calls_click(self):
        await self._send({"action": "click"})
        self.pyautogui.click.assert_called_once()

    async def test_double_click_calls_doubleClick(self):
        await self._send({"action": "double_click"})
        self.pyautogui.doubleClick.assert_called_once()

    async def test_right_click_calls_rightClick(self):
        await self._send({"action": "right_click"})
        self.pyautogui.rightClick.assert_called_once()

    async def test_scroll_calls_scroll(self):
        await self._send({"action": "scroll", "amount": 3.0})
        self.pyautogui.scroll.assert_called_once_with(3)

    async def test_unknown_action_is_ignored(self):
        await self._send({"action": "unknown"})
        self.pyautogui.moveRel.assert_not_called()
        self.pyautogui.click.assert_not_called()

    async def test_malformed_json_is_ignored(self):
        ws = _make_ws(["not-json"])
        # Should not raise.
        await self.server_mod.handle_client(ws)
        self.pyautogui.moveRel.assert_not_called()

    async def test_multiple_messages_in_sequence(self):
        ws = _make_ws([
            json.dumps({"action": "move", "dx": 5, "dy": 5}),
            json.dumps({"action": "click"}),
        ])
        await self.server_mod.handle_client(ws)
        self.assertEqual(self.pyautogui.moveRel.call_count, 1)
        self.assertEqual(self.pyautogui.click.call_count, 1)


if __name__ == "__main__":
    unittest.main()
