#!/usr/bin/env python3
"""Run a versioned Fabushi iOS flow through the Appium WebDriver protocol.

The app is launched by the CI harness before this script starts so credentials
never need to appear in Appium capabilities or Appium logs. Flow files contain
semantic locators and actions only; screen coordinates are deliberately not
part of the v1 contract.
"""

from __future__ import annotations

import argparse
import base64
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

ELEMENT_KEY = "element-6066-11e4-a52e-4f735466cecf"
FLOW_SCHEMA_VERSION = 1


class WebDriverError(RuntimeError):
    pass


class AppiumClient:
    def __init__(self, server_url: str, udid: str, bundle_id: str) -> None:
        self.server_url = server_url.rstrip("/")
        self.udid = udid
        self.bundle_id = bundle_id
        self.session_id: str | None = None

    def request(
        self,
        method: str,
        path: str,
        payload: dict[str, Any] | None = None,
        *,
        timeout: float = 90,
    ) -> Any:
        body = None
        headers = {"Accept": "application/json"}
        if payload is not None:
            body = json.dumps(payload).encode("utf-8")
            headers["Content-Type"] = "application/json"
        request = urllib.request.Request(
            f"{self.server_url}{path}",
            data=body,
            headers=headers,
            method=method,
        )
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                decoded = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            raise WebDriverError(
                f"{method} {path} failed with HTTP {error.code}: {detail}"
            ) from error
        except urllib.error.URLError as error:
            raise WebDriverError(f"{method} {path} failed: {error}") from error
        value = decoded.get("value", decoded)
        if isinstance(value, dict) and value.get("error"):
            raise WebDriverError(
                f"{method} {path} failed: {value.get('error')}: "
                f"{value.get('message', '')}"
            )
        return value

    def create_session(self) -> None:
        response = self.request(
            "POST",
            "/session",
            {
                "capabilities": {
                    "alwaysMatch": {
                        "platformName": "iOS",
                        "appium:automationName": "XCUITest",
                        "appium:udid": self.udid,
                        "appium:bundleId": self.bundle_id,
                        "appium:autoLaunch": False,
                        "appium:noReset": True,
                        "appium:newCommandTimeout": 180,
                        "appium:waitForIdleTimeout": 5,
                    },
                    "firstMatch": [{}],
                }
            },
            timeout=180,
        )
        if isinstance(response, dict):
            self.session_id = response.get("sessionId")
        if not self.session_id:
            raw_request = urllib.request.Request(
                f"{self.server_url}/sessions", method="GET"
            )
            with urllib.request.urlopen(raw_request, timeout=30) as result:
                sessions = json.loads(result.read().decode("utf-8")).get("value", [])
            if sessions:
                self.session_id = sessions[-1].get("id")
        if not self.session_id:
            raise WebDriverError("Appium did not return a session id")

    def close(self) -> None:
        if not self.session_id:
            return
        try:
            self.request("DELETE", f"/session/{self.session_id}", timeout=30)
        finally:
            self.session_id = None

    def _session_path(self, suffix: str) -> str:
        if not self.session_id:
            raise WebDriverError("Appium session is not active")
        return f"/session/{self.session_id}{suffix}"

    def find(self, using: str, value: str) -> str:
        result = self.request(
            "POST",
            self._session_path("/element"),
            {"using": using, "value": value},
            timeout=30,
        )
        if not isinstance(result, dict) or ELEMENT_KEY not in result:
            raise WebDriverError(f"Element not found using={using!r} value={value!r}")
        return str(result[ELEMENT_KEY])

    def wait_for(
        self,
        using: str,
        value: str,
        *,
        timeout: float = 45,
        poll: float = 0.5,
    ) -> str:
        deadline = time.monotonic() + timeout
        last_error: Exception | None = None
        while time.monotonic() < deadline:
            try:
                return self.find(using, value)
            except Exception as error:  # condition polling is intentional
                last_error = error
                time.sleep(poll)
        raise WebDriverError(
            f"Timed out waiting for using={using!r} value={value!r}: {last_error}"
        )

    def click(self, element_id: str) -> None:
        self.request("POST", self._session_path(f"/element/{element_id}/click"), {})

    def send_keys(self, element_id: str, text: str) -> None:
        self.request(
            "POST",
            self._session_path(f"/element/{element_id}/value"),
            {"text": text, "value": list(text)},
        )

    def screenshot(self, path: Path) -> None:
        encoded = self.request("GET", self._session_path("/screenshot"), timeout=60)
        if not isinstance(encoded, str):
            raise WebDriverError("Appium screenshot response is not base64 text")
        path.write_bytes(base64.b64decode(encoded))

    def source(self) -> str:
        source = self.request("GET", self._session_path("/source"), timeout=60)
        return source if isinstance(source, str) else json.dumps(source, ensure_ascii=False)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--udid", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument(
        "--flow",
        default=str(
            Path(__file__).with_name("flows")
            / "global_fabushi_search_open.v1.json"
        ),
    )
    parser.add_argument("--query", default="全球法布施")
    parser.add_argument("--server-url", default="http://127.0.0.1:4723")
    parser.add_argument("--artifacts", required=True)
    return parser.parse_args()


def render(value: str, variables: dict[str, str]) -> str:
    rendered = value
    for key, replacement in variables.items():
        rendered = rendered.replace("{{" + key + "}}", replacement)
    return rendered


def load_flow(path: Path) -> dict[str, Any]:
    flow = json.loads(path.read_text(encoding="utf-8"))
    if flow.get("schemaVersion") != FLOW_SCHEMA_VERSION:
        raise WebDriverError(
            f"Unsupported flow schemaVersion={flow.get('schemaVersion')!r}; "
            f"expected {FLOW_SCHEMA_VERSION}"
        )
    steps = flow.get("steps")
    if not isinstance(steps, list) or not steps:
        raise WebDriverError("Flow must contain a non-empty steps array")
    for index, step in enumerate(steps):
        if not isinstance(step, dict):
            raise WebDriverError(f"Flow step {index} must be an object")
        if "x" in step or "y" in step:
            raise WebDriverError("Flow v1 forbids coordinate-based actions")
        locator = step.get("locator")
        if locator is not None and (
            not isinstance(locator, dict)
            or not isinstance(locator.get("using"), str)
            or not isinstance(locator.get("value"), str)
        ):
            raise WebDriverError(f"Flow step {index} has an invalid locator")
    return flow


def main() -> int:
    args = parse_args()
    artifact_root = Path(args.artifacts)
    screenshot_dir = artifact_root / "screenshots"
    source_dir = artifact_root / "page-source"
    screenshot_dir.mkdir(parents=True, exist_ok=True)
    source_dir.mkdir(parents=True, exist_ok=True)
    timeline_path = artifact_root / "timeline.jsonl"
    timeline_path.write_text("", encoding="utf-8")

    flow = load_flow(Path(args.flow))
    variables = {"query": args.query, "bundleId": args.bundle_id}
    client = AppiumClient(args.server_url, args.udid, args.bundle_id)
    step_index = 0

    def capture(step_name: str, started: float, detail: dict[str, Any]) -> None:
        nonlocal step_index
        safe_name = "".join(
            character if character.isalnum() or character in "-_" else "-"
            for character in step_name
        ).strip("-") or f"step-{step_index}"
        screenshot_path = screenshot_dir / f"{step_index:02d}-{safe_name}.png"
        source_path = source_dir / f"{step_index:02d}-{safe_name}.xml"
        client.screenshot(screenshot_path)
        source_path.write_text(client.source(), encoding="utf-8")
        event = {
            "schemaVersion": FLOW_SCHEMA_VERSION,
            "flow": flow.get("name", Path(args.flow).stem),
            "step": step_index,
            "name": step_name,
            "timestamp": started,
            "screenshot": str(screenshot_path),
            "source": str(source_path),
            **detail,
        }
        with timeline_path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(event, ensure_ascii=False) + "\n")
        print(json.dumps(event, ensure_ascii=False), flush=True)
        step_index += 1

    def run_step(step: dict[str, Any]) -> None:
        action = str(step.get("action", "capture"))
        name = str(step.get("name", action))
        timeout = float(step.get("timeoutSeconds", 60))
        locator = step.get("locator")
        element_id: str | None = None
        if locator is not None:
            using = render(str(locator["using"]), variables)
            value = render(str(locator["value"]), variables)
            element_id = client.wait_for(using, value, timeout=timeout)
        if action in {"capture", "wait", "assertPresent"}:
            return
        if action == "tap":
            if element_id is None:
                raise WebDriverError(f"Step {name!r} requires a locator")
            client.click(element_id)
            return
        if action == "type":
            if element_id is None:
                raise WebDriverError(f"Step {name!r} requires a locator")
            client.click(element_id)
            client.send_keys(element_id, render(str(step.get("text", "")), variables))
            return
        raise WebDriverError(f"Unsupported flow action {action!r} in step {name!r}")

    try:
        client.create_session()
        for step in flow["steps"]:
            started = time.time()
            run_step(step)
            capture(
                str(step.get("name", step.get("action", "capture"))),
                started,
                {"action": step.get("action", "capture")},
            )
        return 0
    except Exception as error:
        print(f"iOS E2E failed: {error}", file=sys.stderr, flush=True)
        if client.session_id:
            try:
                capture("failure", time.time(), {"error": str(error)})
            except Exception as screenshot_error:
                print(
                    f"Could not capture failure diagnostics: {screenshot_error}",
                    file=sys.stderr,
                )
        return 1
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
