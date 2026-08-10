#!/usr/bin/env python3
"""Client for Fabushi's debug-only filesystem E2E control protocol."""

from __future__ import annotations

import argparse
import json
import os
import secrets
import sys
import time
from pathlib import Path
from typing import Any

PROTOCOL = "fabushi.e2e.control.v1"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app-home", required=True)
    parser.add_argument("--method", required=True)
    parser.add_argument("--params", default="{}")
    parser.add_argument("--output")
    parser.add_argument("--timeout", type=float, default=30)
    return parser.parse_args()


def atomic_json(path: Path, value: dict[str, Any]) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    os.replace(temporary, path)


def main() -> int:
    args = parse_args()
    control = (
        Path(args.app_home)
        / "Library"
        / "Application Support"
        / "mahayana-runtime"
        / "e2e-control"
    )
    deadline = time.monotonic() + args.timeout
    ready = control / "ready.json"
    while time.monotonic() < deadline and not ready.is_file():
        time.sleep(0.2)
    if not ready.is_file():
        raise SystemExit(f"E2E control did not become ready at {ready}")

    params = json.loads(args.params)
    if not isinstance(params, dict):
        raise SystemExit("--params must decode to a JSON object")
    request_id = f"req-{secrets.token_hex(8)}"
    response = control / f"response-{request_id}.json"
    request = control / "request.json"
    atomic_json(
        request,
        {
            "protocol": PROTOCOL,
            "id": request_id,
            "method": args.method,
            "params": params,
        },
    )
    while time.monotonic() < deadline and not response.is_file():
        time.sleep(0.2)
    if not response.is_file():
        raise SystemExit(f"E2E control timed out waiting for {args.method}")
    payload = json.loads(response.read_text(encoding="utf-8"))
    response.unlink(missing_ok=True)
    if args.output:
        Path(args.output).write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    print(json.dumps(payload, ensure_ascii=False))
    if payload.get("protocol") != PROTOCOL or payload.get("id") != request_id:
        raise SystemExit("E2E control response identity mismatch")
    if payload.get("ok") is not True:
        raise SystemExit(f"E2E control method failed: {payload.get('error')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
