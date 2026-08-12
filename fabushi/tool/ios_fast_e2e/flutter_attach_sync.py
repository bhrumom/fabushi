#!/usr/bin/env python3
"""Fast iOS Dart sync with a signed-shell baseline and deterministic fallback.

1. Restore the pristine Xcode-built Runner artifact.
2. Repair ShareExtension version metadata and re-sign inner-to-outer while
   preserving Xcode Debug entitlements.
3. Prove that pristine Dart reaches the filesystem E2E control channel.
4. Prefer Flutter's prebuilt HotRunner to sync current Dart without Xcode.
5. If VM-service discovery is unavailable, inject the current debug bundle
   while preserving iOS VM snapshots and re-sign modified nested code.
"""
from __future__ import annotations

import argparse
import json
import os
import plistlib
import selectors
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any, Iterable

PROTOCOL = "fabushi.ios.fast-sync.v2"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument('--project', required=True)
    p.add_argument('--udid', required=True)
    p.add_argument('--application-binary')
    p.add_argument('--bundle-id', required=True)
    p.add_argument('--ready-file', required=True)
    p.add_argument('--timing-file', required=True)
    p.add_argument('--flutter', default='flutter')
    p.add_argument('--target', default='lib/main.dart')
    p.add_argument('--timeout-seconds', type=float, default=120)
    p.add_argument('--dart-define', action='append', default=[])
    return p.parse_args()


def atomic_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + '.tmp')
    tmp.write_text(json.dumps(payload, ensure_ascii=False) + '\n', encoding='utf-8')
    tmp.replace(path)


def exec_cmd(
    cmd: list[str],
    *,
    cwd: Path | None = None,
    timeout: float = 180,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    print(json.dumps({'event': 'fabushi.fastLane.exec', 'argv': cmd}), flush=True)
    completed = subprocess.run(
        cmd,
        cwd=cwd,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        timeout=timeout,
    )
    if completed.stdout:
        print(completed.stdout, end='', flush=True)
    if check and completed.returncode != 0:
        raise RuntimeError(
            f"command failed ({completed.returncode}): {' '.join(cmd)}"
        )
    return completed


def protocol_messages(line: str) -> Iterable[dict[str, Any]]:
    try:
        payload = json.loads(line)
    except json.JSONDecodeError:
        return ()
    if isinstance(payload, dict):
        return (payload,)
    if isinstance(payload, list):
        return tuple(item for item in payload if isinstance(item, dict))
    return ()


def control_path(app_home: Path) -> Path:
    return (
        app_home
        / 'Library'
        / 'Application Support'
        / 'mahayana-runtime'
        / 'e2e-control'
        / 'ready.json'
    )


def clear_control(app_home: Path) -> None:
    directory = control_path(app_home).parent
    if directory.exists():
        shutil.rmtree(directory, ignore_errors=True)


def wait_control(app_home: Path, timeout: float) -> dict[str, Any]:
    ready = control_path(app_home)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if ready.is_file():
            try:
                return json.loads(ready.read_text(encoding='utf-8'))
            except Exception:
                return {'ready': True, 'path': str(ready)}
        time.sleep(.2)
    raise TimeoutError(f'E2E control not ready: {ready}')


def app_home(udid: str, bundle_id: str) -> Path:
    output = exec_cmd(
        ['xcrun', 'simctl', 'get_app_container', udid, bundle_id, 'data'],
        timeout=30,
    ).stdout.strip().splitlines()[-1]
    path = Path(output)
    if not path.is_dir():
        raise RuntimeError(f'invalid app data container: {path}')
    return path


def diagnose(udid: str, label: str) -> None:
    print(json.dumps({'event': 'fabushi.fastLane.diagnose', 'label': label}), flush=True)
    exec_cmd(
        ['xcrun', 'simctl', 'spawn', udid, 'ps', '-ax', '-o', 'pid,ppid,state,command'],
        timeout=20,
        check=False,
    )
    predicate = (
        'process == "Runner" OR eventMessage CONTAINS[c] "flutter" '
        'OR eventMessage CONTAINS[c] "dart" '
        'OR eventMessage CONTAINS[c] "code sign"'
    )
    exec_cmd(
        [
            'xcrun', 'simctl', 'spawn', udid, 'log', 'show', '--last', '3m',
            '--style', 'compact', '--predicate', predicate,
        ],
        timeout=45,
        check=False,
    )


def restore_pristine(app: Path) -> None:
    archive = Path(os.environ.get('RUNNER_TEMP', '')) / 'runner-shell' / 'Runner.app.zip'
    if not archive.is_file():
        raise RuntimeError(f'Runner artifact archive missing: {archive}')
    if app.exists():
        shutil.rmtree(app)
    app.parent.mkdir(parents=True, exist_ok=True)
    exec_cmd(['ditto', '-x', '-k', str(archive), str(app.parent)], timeout=120)
    if not app.is_dir():
        raise RuntimeError(f'Runner.app not restored: {app}')
    host = plistlib.loads((app / 'Info.plist').read_bytes())
    ext_path = app / 'PlugIns' / 'ShareExtension.appex' / 'Info.plist'
    ext = plistlib.loads(ext_path.read_bytes())
    for key in ('CFBundleShortVersionString', 'CFBundleVersion'):
        value = host.get(key)
        if not value:
            raise RuntimeError(f'host missing {key}')
        ext[key] = value
    ext_path.write_bytes(plistlib.dumps(ext, fmt=plistlib.FMT_BINARY, sort_keys=False))
    print(
        json.dumps(
            {
                'event': 'fabushi.fastLane.pristineShell',
                'version': host.get('CFBundleShortVersionString'),
                'build': host.get('CFBundleVersion'),
            }
        ),
        flush=True,
    )


def sign_preserving(app: Path, *, app_framework_modified: bool) -> None:
    framework = app / 'Frameworks' / 'App.framework'
    extension = app / 'PlugIns' / 'ShareExtension.appex'
    nested = 'identifier,requirements,flags,runtime'
    entitled = 'identifier,entitlements,requirements,flags,runtime'
    if app_framework_modified:
        exec_cmd(
            [
                'codesign', '--force', '--sign', '-', '--timestamp=none',
                f'--preserve-metadata={nested}', '--generate-entitlement-der',
                str(framework),
            ],
            timeout=120,
        )
    exec_cmd(
        [
            'codesign', '--force', '--sign', '-', '--timestamp=none',
            f'--preserve-metadata={entitled}', '--generate-entitlement-der',
            str(extension),
        ],
        timeout=120,
    )
    exec_cmd(
        [
            'codesign', '--force', '--sign', '-', '--timestamp=none',
            f'--preserve-metadata={entitled}', '--generate-entitlement-der', str(app),
        ],
        timeout=120,
    )
    exec_cmd(['codesign', '--verify', '--deep', '--strict', str(app)], timeout=60)
    exec_cmd(
        ['codesign', '--display', '--entitlements', ':-', '--xml', str(app)],
        timeout=30,
        check=False,
    )


def install(udid: str, app: Path, bundle_id: str) -> Path:
    exec_cmd(['xcrun', 'simctl', 'install', udid, str(app)], timeout=120)
    return app_home(udid, bundle_id)


def launch_direct(udid: str, bundle_id: str) -> str:
    return exec_cmd(
        ['xcrun', 'simctl', 'launch', '--terminate-running-process', udid, bundle_id],
        timeout=60,
    ).stdout.strip()


def stop_app(udid: str, bundle_id: str) -> None:
    exec_cmd(['xcrun', 'simctl', 'terminate', udid, bundle_id], timeout=20, check=False)


def hotrun(
    args: argparse.Namespace,
    project: Path,
    app: Path,
    home: Path,
    ready_file: Path,
    timing_file: Path,
    timings: dict[str, Any],
) -> bool:
    clear_control(home)
    cmd = [
        args.flutter, 'run', '--machine', '--debug', '--no-pub', '-d', args.udid,
        '--use-application-binary', str(app), '--target', args.target,
    ]
    for define in args.dart_define:
        cmd.append(f'--dart-define={define}')
    started = time.monotonic()
    print(json.dumps({'event': 'fabushi.fastLane.hotrun', 'argv': cmd}), flush=True)
    proc = subprocess.Popen(
        cmd,
        cwd=project,
        env=os.environ.copy(),
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    def stop(_signum: int, _frame: object) -> None:
        if proc.poll() is None:
            proc.terminate()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    assert proc.stdout is not None
    selector = selectors.DefaultSelector()
    selector.register(proc.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + 60
    app_started = False
    try:
        while time.monotonic() < deadline:
            events = selector.select(timeout=.25)
            line = proc.stdout.readline() if events else ''
            if line:
                sys.stdout.write(line)
                sys.stdout.flush()
                for message in protocol_messages(line):
                    if message.get('event') == 'app.started':
                        app_started = True
            if app_started and control_path(home).is_file():
                timings['hotrunMs'] = round((time.monotonic() - started) * 1000)
                timings['strategy'] = 'hotrun'
                payload = {
                    'protocol': PROTOCOL,
                    'strategy': 'hotrun',
                    'appHome': str(home),
                    **timings,
                }
                atomic_json(ready_file, payload)
                atomic_json(timing_file, payload)
                print(json.dumps({'event': 'fabushi.fastLane.ready', **payload}), flush=True)
                while proc.poll() is None:
                    time.sleep(.5)
                return True
            if proc.poll() is not None:
                break
    finally:
        selector.close()
    if proc.poll() is None:
        proc.terminate()
    try:
        proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        proc.kill()
    timings['hotrunAttemptMs'] = round((time.monotonic() - started) * 1000)
    diagnose(args.udid, 'hotrun-timeout')
    return False


def inject_bundle(
    args: argparse.Namespace,
    project: Path,
    app: Path,
    ready_file: Path,
    timing_file: Path,
    timings: dict[str, Any],
) -> None:
    restore_pristine(app)
    framework = app / 'Frameworks' / 'App.framework'
    destination = framework / 'flutter_assets'
    with tempfile.TemporaryDirectory(prefix='fabushi-flutter-bundle-') as temporary:
        source = Path(temporary) / 'flutter_assets'
        started = time.monotonic()
        cmd = [
            args.flutter, 'build', 'bundle', '--debug', '--no-pub',
            '--target-platform=ios', f'--target={args.target}', f'--asset-dir={source}',
        ]
        for define in args.dart_define:
            cmd.append(f'--dart-define={define}')
        exec_cmd(cmd, cwd=project, timeout=180)
        timings['bundleBuildMs'] = round((time.monotonic() - started) * 1000)
        kernel = source / 'kernel_blob.bin'
        if not kernel.is_file() or not kernel.stat().st_size:
            raise RuntimeError('debug bundle missing kernel_blob.bin')
        bootstrap: dict[str, bytes] = {}
        for name in ('vm_snapshot_data', 'isolate_snapshot_data'):
            path = destination / name
            if not path.is_file() or not path.stat().st_size:
                raise RuntimeError(f'pristine shell missing {name}')
            bootstrap[name] = path.read_bytes()
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(source, destination, symlinks=True)
        for name, data in bootstrap.items():
            if not (destination / name).exists():
                (destination / name).write_bytes(data)
        print(
            json.dumps(
                {
                    'event': 'fabushi.fastLane.injectedAssets',
                    'sizes': {
                        name: (destination / name).stat().st_size
                        for name in ('kernel_blob.bin', 'vm_snapshot_data', 'isolate_snapshot_data')
                    },
                }
            ),
            flush=True,
        )
    started = time.monotonic()
    sign_preserving(app, app_framework_modified=True)
    timings['fallbackResignMs'] = round((time.monotonic() - started) * 1000)
    home = install(args.udid, app, args.bundle_id)
    clear_control(home)
    started = time.monotonic()
    launch = launch_direct(args.udid, args.bundle_id)
    try:
        ready = wait_control(home, 30)
    except TimeoutError:
        diagnose(args.udid, 'bundle-inject-timeout')
        raise
    timings['fallbackLaunchMs'] = round((time.monotonic() - started) * 1000)
    timings['strategy'] = 'bundle-inject'
    payload = {
        'protocol': PROTOCOL,
        'strategy': 'bundle-inject',
        'appHome': str(home),
        'launch': launch,
        'control': ready,
        **timings,
    }
    atomic_json(ready_file, payload)
    atomic_json(timing_file, payload)
    print(json.dumps({'event': 'fabushi.fastLane.ready', **payload}), flush=True)


def main() -> int:
    args = parse_args()
    project = Path(args.project).resolve()
    app = (
        Path(args.application_binary).resolve()
        if args.application_binary
        else (project / 'build/ios/iphonesimulator/Runner.app').resolve()
    )
    ready_file = Path(args.ready_file).resolve()
    timing_file = Path(args.timing_file).resolve()
    ready_file.unlink(missing_ok=True)
    timing_file.unlink(missing_ok=True)
    timings: dict[str, Any] = {}
    overall = time.monotonic()

    restore_pristine(app)
    started = time.monotonic()
    sign_preserving(app, app_framework_modified=False)
    timings['baselineResignMs'] = round((time.monotonic() - started) * 1000)
    home = install(args.udid, app, args.bundle_id)
    clear_control(home)
    started = time.monotonic()
    baseline_launch = launch_direct(args.udid, args.bundle_id)
    try:
        baseline = wait_control(home, 15)
    except TimeoutError as error:
        diagnose(args.udid, 'pristine-baseline-timeout')
        raise RuntimeError('preserve-signed pristine Runner did not reach Dart control') from error
    timings['baselineLaunchMs'] = round((time.monotonic() - started) * 1000)
    print(
        json.dumps(
            {
                'event': 'fabushi.fastLane.baselineReady',
                'launch': baseline_launch,
                'control': baseline,
            }
        ),
        flush=True,
    )
    stop_app(args.udid, args.bundle_id)
    clear_control(home)

    if hotrun(args, project, app, home, ready_file, timing_file, timings):
        return 0
    inject_bundle(args, project, app, ready_file, timing_file, timings)
    timings['elapsedMs'] = round((time.monotonic() - overall) * 1000)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
