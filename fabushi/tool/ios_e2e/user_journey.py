#!/usr/bin/env python3
"""Complete real-user iOS journey: login -> install -> chat -> MiniApp -> chat."""
from __future__ import annotations

import argparse
import json
import os
import time
from pathlib import Path
from typing import Any

from appium_flow import AppiumClient, WebDriverError

ELEMENT_KEY = "element-6066-11e4-a52e-4f735466cecf"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--udid", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--artifacts", required=True)
    parser.add_argument("--server-url", default="http://127.0.0.1:4723")
    parser.add_argument("--query", default="全球法布施")
    parser.add_argument("--plugin-id", default="global-dharma")
    parser.add_argument("--username", default="TestAccount")
    parser.add_argument("--password-env", default="TEST_ACCOUNT_TOKEN")
    return parser.parse_args()


class Journey:
    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
        self.root = Path(args.artifacts)
        self.root.mkdir(parents=True, exist_ok=True)
        (self.root / "screenshots").mkdir(exist_ok=True)
        (self.root / "page-source").mkdir(exist_ok=True)
        self.timeline = self.root / "user-journey.jsonl"
        self.timeline.write_text("", encoding="utf-8")
        self.client = AppiumClient(args.server_url, args.udid, args.bundle_id)
        self.index = 0

    def event(self, name: str, started: float, **detail: Any) -> None:
        row = {
            "schemaVersion": 1,
            "step": self.index,
            "name": name,
            "durationMs": round((time.monotonic() - started) * 1000),
            **detail,
        }
        with self.timeline.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")
        print(json.dumps(row, ensure_ascii=False), flush=True)
        self.index += 1

    def capture(self, name: str, started: float, **detail: Any) -> None:
        screenshot = self.root / "screenshots" / f"{self.index:02d}-{name}.png"
        source = self.root / "page-source" / f"{self.index:02d}-{name}.xml"
        self.client.screenshot(screenshot)
        source.write_text(self.client.source(), encoding="utf-8")
        self.event(
            name,
            started,
            screenshot=str(screenshot.relative_to(self.root)),
            source=str(source.relative_to(self.root)),
            **detail,
        )

    def session_path(self, suffix: str) -> str:
        if not self.client.session_id:
            raise WebDriverError("Appium session is not active")
        return f"/session/{self.client.session_id}{suffix}"

    def text(self, element_id: str) -> str:
        value = self.client.request(
            "GET", self.session_path(f"/element/{element_id}/text"), timeout=30
        )
        return str(value or "")

    def clear(self, element_id: str) -> None:
        self.client.request(
            "POST", self.session_path(f"/element/{element_id}/clear"), {}, timeout=30
        )

    def switch_context(self, name: str) -> None:
        self.client.request(
            "POST", self.session_path("/context"), {"name": name}, timeout=30
        )

    def contexts(self) -> list[str]:
        value = self.client.request("GET", self.session_path("/contexts"), timeout=30)
        return [str(item) for item in value] if isinstance(value, list) else []

    def wait_webview_context(self, timeout: float = 60) -> str:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            for context in self.contexts():
                if context != "NATIVE_APP" and "WEBVIEW" in context.upper():
                    return context
            time.sleep(0.5)
        raise WebDriverError("Timed out waiting for MiniApp WebView context")

    def predicate(self, value: str, timeout: float = 45) -> str:
        return self.client.wait_for("-ios predicate string", value, timeout=timeout)

    def wait_source_contains(self, needle: str, timeout: float = 60) -> None:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if needle in self.client.source():
                return
            time.sleep(0.6)
        raise WebDriverError(f"Timed out waiting for visible text: {needle}")

    def open_drawer(self) -> None:
        # Prefer a stable semantic ID when present. Fall back to an edge swipe for
        # the legacy shell so this journey can validate the already-built Runner.
        try:
            button = self.client.wait_for(
                "accessibility id", "e2e.drawer.open", timeout=2
            )
            self.client.click(button)
            return
        except WebDriverError:
            pass
        rect = self.client.request("GET", self.session_path("/window/rect"), timeout=30)
        width = int(rect["width"])
        height = int(rect["height"])
        y = max(100, height // 2)
        self.client.request(
            "POST",
            self.session_path("/actions"),
            {
                "actions": [
                    {
                        "type": "pointer",
                        "id": "drawer-finger",
                        "parameters": {"pointerType": "touch"},
                        "actions": [
                            {
                                "type": "pointerMove",
                                "duration": 0,
                                "x": 1,
                                "y": y,
                                "origin": "viewport",
                            },
                            {"type": "pointerDown", "button": 0},
                            {"type": "pause", "duration": 100},
                            {
                                "type": "pointerMove",
                                "duration": 450,
                                "x": int(width * 0.78),
                                "y": y,
                                "origin": "viewport",
                            },
                            {"type": "pointerUp", "button": 0},
                        ],
                    }
                ]
            },
            timeout=30,
        )

    def send_chat(self, message: str, expected: str) -> None:
        try:
            field = self.client.wait_for(
                "accessibility id", "e2e.chat.message-input", timeout=3
            )
        except WebDriverError:
            field = self.predicate(
                "type == 'XCUIElementTypeTextField' AND "
                "(value CONTAINS '输入' OR label CONTAINS '输入')",
                60,
            )
        self.clear(field)
        self.client.send_keys(field, message)
        try:
            send = self.client.wait_for(
                "accessibility id", "e2e.chat.send", timeout=3
            )
        except WebDriverError:
            send = self.predicate(
                "type == 'XCUIElementTypeButton' AND label == '发送'", 30
            )
        self.client.click(send)
        self.wait_source_contains(expected, 90)

    def run(self) -> None:
        secret = (os.environ.get(self.args.password_env) or "").strip()
        if len(secret) < 32:
            raise WebDriverError(f"{self.args.password_env} is missing")

        self.client.create_session()
        try:
            started = time.monotonic()
            self.client.wait_for("accessibility id", "e2e.chat.list", timeout=60)
            self.capture("app-launched-logged-out", started)

            started = time.monotonic()
            self.open_drawer()
            try:
                login = self.client.wait_for("accessibility id", "e2e.auth.open", timeout=3)
            except WebDriverError:
                login = self.predicate("label == '登录 / 注册' OR name == '登录 / 注册'", 30)
            self.client.click(login)

            try:
                username = self.client.wait_for(
                    "accessibility id", "e2e.auth.username", timeout=3
                )
            except WebDriverError:
                username = self.predicate(
                    "type == 'XCUIElementTypeTextField' AND "
                    "(value == '请输入账号或邮箱' OR label == '请输入账号或邮箱')",
                    30,
                )
            try:
                password = self.client.wait_for(
                    "accessibility id", "e2e.auth.password", timeout=3
                )
            except WebDriverError:
                password = self.predicate("type == 'XCUIElementTypeSecureTextField'", 30)

            self.client.send_keys(username, self.args.username)
            self.client.send_keys(password, secret)
            try:
                submit = self.client.wait_for(
                    "accessibility id", "e2e.auth.submit", timeout=3
                )
            except WebDriverError:
                submit = self.predicate(
                    "type == 'XCUIElementTypeButton' AND label == '登录'", 30
                )
            self.client.click(submit)
            self.client.wait_absent(
                "-ios predicate string",
                "type == 'XCUIElementTypeSecureTextField'",
                timeout=45,
            )
            self.client.wait_for("accessibility id", "e2e.chat.search", timeout=30)
            self.capture(
                "ui-login-succeeded",
                started,
                username=self.args.username,
                secret="[redacted]",
            )

            started = time.monotonic()
            search = self.client.wait_for("accessibility id", "e2e.chat.search", timeout=30)
            self.clear(search)
            self.client.send_keys(search, self.args.query)
            self.client.wait_for(
                "accessibility id",
                f"e2e.miniapp.result.{self.args.plugin_id}.registry",
                timeout=60,
            )
            self.client.wait_absent(
                "accessibility id",
                f"e2e.miniapp.result.{self.args.plugin_id}.installed",
                timeout=3,
            )
            self.capture(
                "marketplace-search-uninstalled", started, query=self.args.query
            )

            started = time.monotonic()
            install = self.client.wait_for(
                "accessibility id",
                f"e2e.miniapp.install.{self.args.plugin_id}",
                timeout=30,
            )
            self.client.click(install)
            installed = self.client.wait_for(
                "accessibility id",
                f"e2e.miniapp.result.{self.args.plugin_id}.installed",
                timeout=120,
            )
            self.capture("marketplace-installed", started)
            self.client.click(installed)
            self.client.wait_for(
                "accessibility id",
                f"e2e.miniapp.chat.{self.args.plugin_id}.installed",
                timeout=60,
            )

            started = time.monotonic()
            self.send_chat("/status", "已读取全球法布施状态")
            self.capture("chat-status-response", started, message="/status")

            started = time.monotonic()
            open_button = self.client.wait_for(
                "accessibility id",
                f"e2e.miniapp.open.{self.args.plugin_id}",
                timeout=30,
            )
            self.client.click(open_button)
            self.client.wait_for(
                "accessibility id",
                f"e2e.miniapp.host.{self.args.plugin_id}.ready",
                timeout=120,
            )
            self.capture("miniapp-host-ready", started)

            started = time.monotonic()
            webview = self.wait_webview_context(60)
            self.switch_context(webview)
            status = self.client.wait_for(
                "css selector", 'button[data-tool="status"]', timeout=45
            )
            self.client.click(status)
            output = self.client.wait_for("css selector", "#out", timeout=30)
            deadline = time.monotonic() + 60
            before = ""
            while time.monotonic() < deadline:
                before = self.text(output)
                if all(value in before for value in ("running", "loops", "sent")):
                    break
                time.sleep(0.5)
            else:
                raise WebDriverError("MiniApp /status did not render structured state")

            logs = self.client.wait_for(
                "css selector", 'button[data-tool="logs"]', timeout=30
            )
            self.client.click(logs)
            deadline = time.monotonic() + 60
            while time.monotonic() < deadline:
                after = self.text(output)
                if after != before and ("entries" in after or "已读取日志" in after):
                    break
                time.sleep(0.5)
            else:
                raise WebDriverError("MiniApp /logs did not update #out")
            self.capture(
                "miniapp-webview-status-and-logs", started, context=webview
            )

            self.switch_context("NATIVE_APP")
            try:
                close = self.client.wait_for(
                    "accessibility id",
                    f"e2e.miniapp.host.{self.args.plugin_id}.close",
                    timeout=5,
                )
                self.client.click(close)
            except WebDriverError:
                # Native back button is acceptable if the host does not expose a
                # dedicated close semantic in an older prebuilt shell.
                self.client.request("POST", self.session_path("/back"), {}, timeout=30)
            self.client.wait_for(
                "accessibility id",
                f"e2e.miniapp.chat.{self.args.plugin_id}.installed",
                timeout=45,
            )
            started = time.monotonic()
            self.send_chat("/logs", "已读取日志")
            self.capture("chat-still-works-after-miniapp", started, message="/logs")

            (self.root / "journey-result.json").write_text(
                json.dumps(
                    {
                        "ok": True,
                        "pluginId": self.args.plugin_id,
                        "query": self.args.query,
                        "stages": self.index,
                    },
                    ensure_ascii=False,
                    indent=2,
                )
                + "\n",
                encoding="utf-8",
            )
        except Exception as error:
            started = time.monotonic()
            try:
                self.capture("failure", started, error=str(error))
            except Exception:
                self.event("failure", started, error=str(error))
            (self.root / "journey-result.json").write_text(
                json.dumps(
                    {"ok": False, "error": str(error), "stages": self.index},
                    ensure_ascii=False,
                    indent=2,
                )
                + "\n",
                encoding="utf-8",
            )
            raise
        finally:
            self.client.close()


def main() -> int:
    Journey(parse_args()).run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
