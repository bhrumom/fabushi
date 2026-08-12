#!/usr/bin/env python3
"""Inject the current Flutter debug bundle into a compatible prebuilt iOS shell.

The fast lane deliberately avoids Xcode and avoids Dart VM service discovery.
It builds only Flutter's debug asset/kernel bundle, replaces
Runner.app/Frameworks/App.framework/flutter_assets, ad-hoc re-signs the app,
installs the updated shell on the Simulator, launches it, and waits for the
existing debug-only E2E control channel to prove the current Dart code booted.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

PROTOCOL = "fabushi.ios.flutter-bundle-inject.v1"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True)
    parser.add_argument("--udid", required=True)
    parser.add_argument("--application-binary")
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--ready-file", required=True)
    parser.add_argument("--timing-file", required=True)
    parser.add_argument("--flutter", default="flutter")
    parser.add_argument("--target", default="lib/main.dart")
    parser.add_argument("--timeout-seconds", type=float, default=120)
    parser.add_argument("--dart-define", action="append", default=[])
    return parser.parse_args()


def atomic_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(payload, ensure_ascii=False) + "\n", encoding="utf-8")
    temporary.replace(path)


def run(command: list[str], *, cwd: Path | None = None, timeout: float = 180) -> str:
    print(json.dumps({"event": "fabushi.fastLane.exec", "argv": command}), flush=True)
    completed = subprocess.run(
        command,
        cwd=cwd,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        timeout=timeout,
    )
    if completed.stdout:
        print(completed.stdout, end="", flush=True)
    if completed.returncode != 0:
        raise RuntimeError(
            f"Command failed with exit code {completed.returncode}: {' '.join(command)}"
        )
    return completed.stdout


def wait_for_control(app_home: Path, timeout_seconds: float) -> Path:
    ready = (
        app_home
        / "Library"
        / "Application Support"
        / "mahayana-runtime"
        / "e2e-control"
        / "ready.json"
    )
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        if ready.is_file():
            return ready
        time.sleep(0.2)
    raise RuntimeError(f"E2E control did not become ready at {ready}")


def main() -> int:
    args = parse_args()
    project = Path(args.project).resolve()
    application_binary = (
        Path(args.application_binary).resolve()
        if args.application_binary
        else (project / "build/ios/iphonesimulator/Runner.app").resolve()
    )
    ready_file = Path(args.ready_file).resolve()
    timing_file = Path(args.timing_file).resolve()
    ready_file.unlink(missing_ok=True)
    timing_file.unlink(missing_ok=True)

    if not project.is_dir():
        raise SystemExit(f"Project directory does not exist: {project}")
    if not application_binary.is_dir():
        raise SystemExit(f"Prebuilt application does not exist: {application_binary}")

    app_framework = application_binary / "Frameworks" / "App.framework"
    asset_destination = app_framework / "flutter_assets"
    if not app_framework.is_dir():
        raise SystemExit(f"Prebuilt App.framework does not exist: {app_framework}")

    overall_started = time.monotonic()
    timings: dict[str, int] = {}

    with tempfile.TemporaryDirectory(prefix="fabushi-flutter-bundle-") as temporary:
        asset_source = Path(temporary) / "flutter_assets"
        build_started = time.monotonic()
        command = [
            args.flutter,
            "build",
            "bundle",
            "--debug",
            "--no-pub",
            "--target-platform=ios",
            f"--target={args.target}",
            f"--asset-dir={asset_source}",
        ]
        for define in args.dart_define:
            command.append(f"--dart-define={define}")
        run(command, cwd=project, timeout=max(180, args.timeout_seconds))
        timings["bundleBuildMs"] = round((time.monotonic() - build_started) * 1000)

        kernel = asset_source / "kernel_blob.bin"
        if not kernel.is_file() or kernel.stat().st_size == 0:
            raise RuntimeError(f"Debug bundle did not produce kernel_blob.bin at {kernel}")

        inject_started = time.monotonic()
        if asset_destination.exists():
            shutil.rmtree(asset_destination)
        shutil.copytree(asset_source, asset_destination, symlinks=True)
        timings["assetInjectMs"] = round((time.monotonic() - inject_started) * 1000)

    sign_started = time.monotonic()
    run(
        [
            "codesign",
            "--force",
            "--deep",
            "--sign",
            "-",
            "--timestamp=none",
            str(application_binary),
        ],
        timeout=120,
    )
    run(["codesign", "--verify", "--deep", "--strict", str(application_binary)], timeout=60)
    timings["resignMs"] = round((time.monotonic() - sign_started) * 1000)

    install_started = time.monotonic()
    run(["xcrun", "simctl", "install", args.udid, str(application_binary)], timeout=120)
    app_home_text = run(
        ["xcrun", "simctl", "get_app_container", args.udid, args.bundle_id, "data"],
        timeout=30,
    ).strip().splitlines()[-1]
    app_home = Path(app_home_text)
    if not app_home.is_dir():
        raise RuntimeError(f"Could not resolve application data container: {app_home}")
    timings["installMs"] = round((time.monotonic() - install_started) * 1000)

    launch_started = time.monotonic()
    launch_output = run(
        [
            "xcrun",
            "simctl",
            "launch",
            "--terminate-running-process",
            args.udid,
            args.bundle_id,
        ],
        timeout=60,
    ).strip()
    control_ready = wait_for_control(app_home, args.timeout_seconds)
    timings["launchToControlReadyMs"] = round((time.monotonic() - launch_started) * 1000)
    timings["elapsedMs"] = round((time.monotonic() - overall_started) * 1000)

    payload: dict[str, Any] = {
        "protocol": PROTOCOL,
        "bundleId": args.bundle_id,
        "applicationBinary": str(application_binary),
        "appHome": str(app_home),
        "controlReady": str(control_ready),
        "launchOutput": launch_output,
        **timings,
    }
    atomic_json(ready_file, payload)
    atomic_json(timing_file, payload)
    print(json.dumps({"event": "fabushi.fastLane.ready", **payload}), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
