#!/usr/bin/env python3
"""Probe and validate the deterministic iOS Marketplace distribution fixture."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import time
import urllib.parse
import urllib.request
from typing import Any

PROTOCOL = "fabushi.marketplace.fixture.v1"
PLUGIN_ID = "global-dharma"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pid-file", required=True)
    parser.add_argument("--log-file", required=True)
    parser.add_argument("--metadata-file", required=True)
    parser.add_argument("--package-file")
    parser.add_argument("--query", default="全球法布施")
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--full-contract", action="store_true")
    parser.add_argument("--github-env")
    parser.add_argument("--mode-file")
    return parser.parse_args()


def read_json(path: Path) -> dict[str, Any]:
    decoded = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(decoded, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return decoded


def diagnostics(log_path: Path) -> str:
    if not log_path.exists():
        return ""
    return log_path.read_text(encoding="utf-8", errors="replace")


def wait_ready(args: argparse.Namespace) -> tuple[str, dict[str, Any], urllib.request.OpenerDirector]:
    pid_path = Path(args.pid_file)
    log_path = Path(args.log_file)
    metadata_path = Path(args.metadata_file)
    pid = int(pid_path.read_text(encoding="utf-8").strip())
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    deadline = time.monotonic() + args.timeout
    last_error: Exception | None = None
    base_url: str | None = None

    while time.monotonic() < deadline:
        try:
            os.kill(pid, 0)
        except OSError as error:
            raise RuntimeError(
                f"Marketplace fixture exited before readiness: {error}\n{diagnostics(log_path)}"
            ) from error
        try:
            if metadata_path.exists():
                metadata = read_json(metadata_path)
                candidate = metadata.get("baseUrl")
                if isinstance(candidate, str) and candidate.startswith("http://127.0.0.1:"):
                    base_url = candidate.rstrip("/")
                    with opener.open(f"{base_url}/healthz", timeout=2) as response:
                        health = json.loads(response.read().decode("utf-8"))
                    if health.get("ok") is True and health.get("protocol") == PROTOCOL:
                        if metadata.get("protocol") != PROTOCOL:
                            raise ValueError("fixture metadata protocol does not match readiness protocol")
                        if metadata.get("pluginId") != PLUGIN_ID:
                            raise ValueError("fixture metadata does not identify global-dharma")
                        return base_url, metadata, opener
        except Exception as error:
            last_error = error
        time.sleep(0.1)

    raise RuntimeError(
        "Marketplace fixture did not become ready within "
        f"{args.timeout:g} seconds; base_url={base_url!r}; last_error={last_error!r}\n"
        f"{diagnostics(log_path)}"
    )


def verify_full_contract(
    base_url: str,
    metadata: dict[str, Any],
    opener: urllib.request.OpenerDirector,
    query: str,
    package_file: Path,
) -> None:
    browse_url = f"{base_url}/v1/marketplace/plugins?" + urllib.parse.urlencode(
        {"q": query, "platform": "mobile"}
    )
    with opener.open(browse_url, timeout=3) as response:
        browse = json.loads(response.read().decode("utf-8"))
    rows = [row for row in browse.get("plugins", []) if row.get("pluginId") == PLUGIN_ID]
    if len(rows) != 1:
        raise ValueError(f"expected one exact {PLUGIN_ID} browse result; got {rows!r}")
    row = rows[0]
    version = str(metadata["version"])
    if row.get("latestVersion") != version:
        raise ValueError("browse version does not match fixture metadata")

    release_url = f"{base_url}/v1/marketplace/plugins/{PLUGIN_ID}/releases/{version}"
    with opener.open(release_url, timeout=3) as response:
        release = json.loads(response.read().decode("utf-8"))
    if release.get("pluginId") != PLUGIN_ID or release.get("version") != version:
        raise ValueError("release identity does not match fixture metadata")
    if release.get("source") != metadata.get("source"):
        raise ValueError("release source identity does not match fixture metadata")

    with opener.open(str(release["downloadUrl"]), timeout=3) as response:
        payload = response.read()
    digest = hashlib.sha256(payload).hexdigest()
    if digest != metadata.get("packageSha256") or digest != release.get("packageSha256"):
        raise ValueError("download SHA-256 does not match fixture identity")
    if len(payload) != metadata.get("packageSize") or len(payload) != release.get("packageSize"):
        raise ValueError("download size does not match fixture identity")
    if payload != package_file.read_bytes():
        raise ValueError("downloaded fixture bytes differ from the canonical package file")


def append_line(path_value: str | None, line: str) -> None:
    if not path_value:
        return
    path = Path(path_value)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(line + "\n")


def main() -> int:
    args = parse_args()
    base_url, metadata, opener = wait_ready(args)
    if args.full_contract:
        if not args.package_file:
            raise SystemExit("--package-file is required with --full-contract")
        verify_full_contract(
            base_url,
            metadata,
            opener,
            args.query,
            Path(args.package_file),
        )
    append_line(args.github_env, f"MARKETPLACE_API_BASE_URL={base_url}")
    append_line(args.mode_file, f"apiBaseUrl={base_url}")
    print(
        json.dumps(
            {
                "protocol": PROTOCOL,
                "ready": True,
                "baseUrl": base_url,
                "pluginId": metadata["pluginId"],
                "version": metadata["version"],
                "packageSha256": metadata["packageSha256"],
                "fullContract": bool(args.full_contract),
            },
            ensure_ascii=False,
        ),
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
