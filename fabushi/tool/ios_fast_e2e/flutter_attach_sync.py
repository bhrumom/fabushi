#!/usr/bin/env python3
"""Attach Flutter HotRunner before launch and sync current Dart code to iOS.

Designed for the fast iOS PR lane: install a compatible prebuilt debug Runner.app,
provision the sandbox, start this controller in the background, and let it launch
the app only after `flutter attach --machine` is listening. The controller keeps
the attach process resident for the duration of the UI test.
"""

from __future__ import annotations

import argparse
import json
import os
import selectors
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Iterable


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True)
    parser.add_argument("--udid", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--ready-file", required=True)
    parser.add_argument("--timing-file", required=True)
    parser.add_argument("--flutter", default="flutter")
    parser.add_argument("--target", default="lib/main.dart")
    parser.add_argument("--timeout-seconds", type=float, default=180)
    parser.add_argument("--dart-define", action="append", default=[])
    return parser.parse_args()


def protocol_messages(line: str) -> Iterable[dict[str, Any]]:
    try:
        payload = json.loads(line)
    except json.JSONDecodeError:
        return ()
    if isinstance(payload, dict):
        return (payload,)
    if isinstance(payload, list):
        return tuple(row for row in payload if isinstance(row, dict))
    return ()


def atomic_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(payload, ensure_ascii=False) + "\n", encoding="utf-8")
    temp.replace(path)


def main() -> int:
    args = parse_args()
    project = Path(args.project).resolve()
    ready_file = Path(args.ready_file).resolve()
    timing_file = Path(args.timing_file).resolve()
    ready_file.unlink(missing_ok=True)
    timing_file.unlink(missing_ok=True)

    command = [
        args.flutter,
        "attach",
        "--machine",
        "--debug",
        "-d",
        args.udid,
        "--app-id",
        args.bundle_id,
        "--target",
        args.target,
    ]
    for define in args.dart_define:
        command.append(f"--dart-define={define}")

    started = time.monotonic()
    process = subprocess.Popen(
        command,
        cwd=project,
        env=os.environ.copy(),
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    def stop_child(_signum: int, _frame: object) -> None:
        if process.poll() is None:
            process.terminate()

    signal.signal(signal.SIGTERM, stop_child)
    signal.signal(signal.SIGINT, stop_child)

    launched = False
    app_id: str | None = None
    debug_uri: str | None = None
    deadline = started + args.timeout_seconds

    assert process.stdout is not None
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    while True:
        if time.monotonic() > deadline and not ready_file.exists():
            process.terminate()
            raise SystemExit(
                f"flutter attach did not reach app.started within {args.timeout_seconds:.0f}s"
            )

        events = selector.select(timeout=0.25)
        line = process.stdout.readline() if events else ""
        if line:
            sys.stdout.write(line)
            sys.stdout.flush()
            for message in protocol_messages(line):
                event = message.get("event")
                params = message.get("params")
                if not isinstance(params, dict):
                    params = {}
                if event == "app.start":
                    raw_app_id = params.get("appId")
                    if isinstance(raw_app_id, str):
                        app_id = raw_app_id
                    if not launched:
                        launch_started = time.monotonic()
                        completed = subprocess.run(
                            [
                                "xcrun",
                                "simctl",
                                "launch",
                                "--terminate-running-process",
                                args.udid,
                                args.bundle_id,
                            ],
                            env=os.environ.copy(),
                            stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT,
                            text=True,
                            timeout=60,
                        )
                        print(completed.stdout, end="", flush=True)
                        if completed.returncode != 0:
                            process.terminate()
                            raise SystemExit(
                                f"simctl launch failed with exit code {completed.returncode}"
                            )
                        launched = True
                        print(
                            json.dumps(
                                {
                                    "event": "fabushi.fastLane.launched",
                                    "elapsedMs": round((time.monotonic() - launch_started) * 1000),
                                }
                            ),
                            flush=True,
                        )
                elif event == "app.debugPort":
                    ws_uri = params.get("wsUri")
                    if isinstance(ws_uri, str):
                        debug_uri = ws_uri
                elif event == "app.started" and not ready_file.exists():
                    ready_payload = {
                        "protocol": "fabushi.ios.flutter-attach-sync.v1",
                        "appId": app_id or params.get("appId"),
                        "debugUri": debug_uri,
                        "elapsedMs": round((time.monotonic() - started) * 1000),
                    }
                    atomic_json(ready_file, ready_payload)
                    atomic_json(timing_file, ready_payload)
                    print(json.dumps({"event": "fabushi.fastLane.ready", **ready_payload}), flush=True)
                    # Keep reading so flutter attach remains resident while Appium runs.
                    deadline = float("inf")
        elif process.poll() is not None:
            break
        else:
            time.sleep(0.05)

    return_code = process.wait()
    if not ready_file.exists():
        return return_code or 1
    return return_code


if __name__ == "__main__":
    raise SystemExit(main())
