#!/usr/bin/env python3
import json
import os
import pathlib
import select
import socket
import subprocess
import sys
import time

PROTOCOL = "fabushi.rustdesk-sidecar.v1"
BOOTSTRAP_PROTOCOL = "fabushi.rustdesk-host-bootstrap.v1"
TIMEOUT = 90.0


def wait_port(host: str, port: int, timeout: float = 20.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with socket.create_connection((host, port), timeout=1):
                return
        except OSError:
            time.sleep(0.25)
    raise RuntimeError(f"port {host}:{port} did not become ready")


def read_json_line(proc: subprocess.Popen, timeout: float):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            stderr = proc.stderr.read() if proc.stderr else ""
            raise RuntimeError(f"process exited {proc.returncode}: {stderr[-4000:]}")
        ready, _, _ = select.select([proc.stdout], [], [], min(0.5, max(0.0, deadline - time.monotonic())))
        if not ready:
            continue
        line = proc.stdout.readline()
        if not line:
            continue
        try:
            return json.loads(line)
        except json.JSONDecodeError as exc:
            raise RuntimeError(f"invalid JSON event: {line!r}") from exc
    raise TimeoutError("timed out waiting for JSON event")


def bootstrap(binary: str, env: dict[str, str]):
    command = json.dumps({"type": "rotateTemporaryPassword"}) + "\n"
    result = subprocess.run(
        [binary], input=command, text=True, capture_output=True, env=env, timeout=8, check=False
    )
    lines = [line for line in result.stdout.splitlines() if line.strip()]
    if not lines:
        return None
    value = json.loads(lines[-1])
    if value.get("protocol") != BOOTSTRAP_PROTOCOL or value.get("type") != "hostInfo":
        return None
    peer = value.get("peerId")
    password = value.get("temporaryPassword")
    if not isinstance(peer, str) or not peer or not isinstance(password, str) or len(password) < 6:
        return None
    return peer, password


def main() -> int:
    required = ["HBBS_BIN", "HBBR_BIN", "FABUSHI_HOST_DAEMON_BIN", "FABUSHI_HOST_BOOTSTRAP_BIN", "FABUSHI_SIDECAR_BIN"]
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        raise RuntimeError(f"missing binaries: {', '.join(missing)}")

    root = pathlib.Path(os.environ.get("RUNNER_TEMP", "/tmp")) / "fabushi-rustdesk-real-e2e"
    server_dir = root / "server"
    home_dir = root / "home"
    server_dir.mkdir(parents=True, exist_ok=True)
    home_dir.mkdir(parents=True, exist_ok=True)

    base_env = os.environ.copy()
    base_env["HOME"] = str(home_dir)
    base_env["DISPLAY"] = base_env.get("DISPLAY", ":99")
    base_env["RUST_LOG"] = "info"

    processes: list[subprocess.Popen] = []
    log_files = []
    try:
        for name, binary, args in [
            ("hbbr", os.environ["HBBR_BIN"], ["-b", "127.0.0.1", "-p", "21117"]),
            ("hbbs", os.environ["HBBS_BIN"], ["-b", "127.0.0.1", "-p", "21116", "-r", "127.0.0.1:21117"]),
        ]:
            log = open(root / f"{name}.log", "w+", encoding="utf-8")
            log_files.append(log)
            proc = subprocess.Popen([binary, *args], cwd=server_dir, env=base_env, stdout=log, stderr=subprocess.STDOUT, text=True)
            processes.append(proc)

        wait_port("127.0.0.1", 21116)
        wait_port("127.0.0.1", 21117)

        key_path = server_dir / "id_ed25519.pub"
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline and not key_path.exists():
            time.sleep(0.25)
        if not key_path.exists():
            raise RuntimeError("hbbs did not generate a public key")
        public_key = key_path.read_text(encoding="utf-8").strip()
        if len(public_key) < 16:
            raise RuntimeError("hbbs public key is invalid")

        managed_env = base_env.copy()
        managed_env["FABUSHI_RUSTDESK_RENDEZVOUS_SERVER"] = "127.0.0.1:21116"
        managed_env["FABUSHI_RUSTDESK_PUBLIC_KEY"] = public_key

        host_log = open(root / "host.log", "w+", encoding="utf-8")
        log_files.append(host_log)
        host = subprocess.Popen([os.environ["FABUSHI_HOST_DAEMON_BIN"]], env=managed_env, stdout=host_log, stderr=subprocess.STDOUT, text=True)
        processes.append(host)

        credentials = None
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline and credentials is None:
            if host.poll() is not None:
                raise RuntimeError(f"host daemon exited early with {host.returncode}")
            credentials = bootstrap(os.environ["FABUSHI_HOST_BOOTSTRAP_BIN"], managed_env)
            if credentials is None:
                time.sleep(1)
        if credentials is None:
            raise RuntimeError("host IPC never exposed peer id + temporary password")
        peer_id, password = credentials

        sidecar = subprocess.Popen(
            [os.environ["FABUSHI_SIDECAR_BIN"]], env=managed_env,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, bufsize=1,
        )
        processes.append(sidecar)
        assert sidecar.stdin is not None
        sidecar.stdin.write(json.dumps({"type": "hello", "protocol": PROTOCOL}) + "\n")
        sidecar.stdin.flush()
        hello = read_json_line(sidecar, 10)
        if hello.get("protocol") != PROTOCOL or hello.get("type") != "hello":
            raise RuntimeError(f"invalid sidecar hello: {hello}")

        session_id = "ci-real-relay-session"
        sidecar.stdin.write(json.dumps({
            "type": "open",
            "sessionId": session_id,
            "peerId": peer_id,
            "password": password,
            "forceRelay": True,
            "grant": {"display": True, "input": True, "clipboard": False, "fileTransfer": False, "audio": False},
        }) + "\n")
        sidecar.stdin.flush()

        saw_ready = False
        saw_relay = False
        saw_frame_begin = False
        saw_frame_end = False
        errors = []
        deadline = time.monotonic() + TIMEOUT
        while time.monotonic() < deadline and not (saw_ready and saw_relay and saw_frame_begin and saw_frame_end):
            event = read_json_line(sidecar, min(5.0, max(0.1, deadline - time.monotonic())))
            if event.get("sessionId") not in (None, session_id):
                raise RuntimeError(f"cross-session event: {event}")
            kind = event.get("type")
            detail = event.get("detail") if isinstance(event.get("detail"), dict) else {}
            if kind == "ready":
                saw_ready = True
            elif kind == "route":
                route = detail.get("route") or detail.get("kind") or detail.get("selectedRoute")
                saw_relay = saw_relay or route == "relay" or "relay" in json.dumps(detail).lower()
            elif kind == "frameBegin":
                saw_frame_begin = True
            elif kind == "frameEnd":
                saw_frame_end = True
            elif kind == "error":
                errors.append(event)
                if len(errors) >= 3:
                    raise RuntimeError(f"sidecar connection errors: {errors}")

        if not saw_ready:
            raise RuntimeError("real RustDesk session never became ready")
        if not saw_frame_begin or not saw_frame_end:
            raise RuntimeError("real RustDesk session never produced a complete display frame")
        # Force-relay is a hard input to the RustDesk peer. Require provider route
        # evidence as well so a test cannot silently pass on a direct connection.
        if not saw_relay:
            raise RuntimeError("force-relay session did not report relay route")

        for command in [
            {"type": "mouse", "sessionId": session_id, "mask": 0, "x": 8, "y": 8},
            {"type": "key", "sessionId": session_id, "name": "Shift", "press": True},
            {"type": "key", "sessionId": session_id, "name": "Shift", "press": False},
            {"type": "close", "sessionId": session_id},
        ]:
            sidecar.stdin.write(json.dumps(command) + "\n")
            sidecar.stdin.flush()

        closed = False
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline and not closed:
            event = read_json_line(sidecar, min(3.0, max(0.1, deadline - time.monotonic())))
            if event.get("type") in ("closed", "closeSuccess") and event.get("sessionId") == session_id:
                closed = True
            if event.get("type") == "error":
                raise RuntimeError(f"provider rejected input/close during real session: {event}")
        if not closed:
            raise RuntimeError("real RustDesk session did not close cleanly")

        print(json.dumps({
            "protocol": "fabushi.rustdesk-real-e2e.v1",
            "result": "pass",
            "peerIdLength": len(peer_id),
            "relay": True,
            "displayFrame": True,
            "inputCommands": True,
            "credentialSource": "local-ipc",
            "rendezvous": "ephemeral-actions-loopback",
        }))
        return 0
    finally:
        for proc in reversed(processes):
            if proc.poll() is None:
                proc.terminate()
        deadline = time.monotonic() + 5
        for proc in reversed(processes):
            if proc.poll() is None:
                try:
                    proc.wait(timeout=max(0.1, deadline - time.monotonic()))
                except subprocess.TimeoutExpired:
                    proc.kill()
        for handle in log_files:
            handle.flush()
            handle.close()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"RUSTDESK_REAL_E2E_FAILED: {exc}", file=sys.stderr)
        raise
