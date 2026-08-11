#!/usr/bin/env python3
"""Loopback E2E API gateway for the iOS user-journey test.

It adds TestAccount password-login semantics in front of the deterministic
Marketplace fixture. The app still executes the production Rust password-login
and Marketplace clients; only the remote HTTP service is replaced in CI.
Secrets are never logged and are compared with hmac.compare_digest.
"""
from __future__ import annotations

import argparse
import hmac
import http.server
import json
import os
import socketserver
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

PROTOCOL = "fabushi.ios-e2e-api.v1"
USERNAME = "TestAccount"
USER_ID = "user:test_account"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--upstream-base-url", required=True)
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=0)
    return p.parse_args()


def _secret() -> str:
    value = (os.environ.get("TEST_ACCOUNT_TOKEN") or os.environ.get("MAHAYANA_TEST_ACCOUNT_TOKEN") or "").strip()
    if len(value) < 32:
        raise RuntimeError("TEST_ACCOUNT_TOKEN is required and must be secret-strength")
    return value


def _user() -> dict[str, Any]:
    return {
        "id": USER_ID,
        "userId": USER_ID,
        "username": USERNAME,
        "nickname": USERNAME,
        "email": "",
        "membership": {"type": "lifetime", "active": True},
        "isTestAccount": True,
    }


class Server(http.server.ThreadingHTTPServer):
    daemon_threads = True

    def server_bind(self) -> None:
        socketserver.TCPServer.server_bind(self)
        host, port = self.server_address[:2]
        self.server_name, self.server_port = str(host), int(port)


class Handler(http.server.BaseHTTPRequestHandler):
    upstream: str
    secret: str

    def log_message(self, fmt: str, *args: object) -> None:  # noqa: A002
        print(json.dumps({"protocol": PROTOCOL, "request": self.requestline, "message": fmt % args}, ensure_ascii=False), flush=True)

    def _json(self, status: int, payload: dict[str, Any]) -> None:
        body = (json.dumps(payload, ensure_ascii=False) + "\n").encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _authorized(self) -> bool:
        supplied = self.headers.get("Authorization", "")
        if not supplied.startswith("Bearer "):
            return False
        return hmac.compare_digest(supplied[7:].encode(), self.secret.encode())

    def _proxy(self) -> None:
        target = self.upstream.rstrip("/") + self.path
        body = None
        if self.command in {"POST", "PUT", "PATCH"}:
            try:
                length = int(self.headers.get("Content-Length", "0"))
            except ValueError:
                length = 0
            body = self.rfile.read(length) if length else b""
        headers = {"Accept": self.headers.get("Accept", "application/json")}
        if self.headers.get("Content-Type"):
            headers["Content-Type"] = self.headers["Content-Type"]
        if self.headers.get("Authorization"):
            headers["Authorization"] = self.headers["Authorization"]
        req = urllib.request.Request(target, data=body, headers=headers, method=self.command)
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        try:
            with opener.open(req, timeout=30) as resp:
                payload = resp.read()
                status = resp.status
                content_type = resp.headers.get("Content-Type", "application/octet-stream")
        except urllib.error.HTTPError as err:
            payload = err.read()
            status = err.code
            content_type = err.headers.get("Content-Type", "application/json")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_POST(self) -> None:  # noqa: N802
        path = urllib.parse.urlsplit(self.path).path
        if path == "/api/auth/login":
            try:
                length = int(self.headers.get("Content-Length", "0"))
                login = json.loads(self.rfile.read(length).decode("utf-8"))
            except Exception:
                self._json(400, {"error": "invalid_login_request", "message": "invalid login request"})
                return
            username = str(login.get("username", "")).strip()
            password = str(login.get("password", ""))
            if username != USERNAME or not hmac.compare_digest(password.encode(), self.secret.encode()):
                self._json(401, {"error": "invalid_credentials", "message": "账号或密码错误"})
                return
            self._json(200, {"accessToken": self.secret, "tokenType": "Bearer", "username": USERNAME, "userId": USER_ID, "user": _user()})
            return
        if path == "/api/auth/logout":
            if not self._authorized():
                self._json(401, {"error": "unauthorized"})
                return
            self._json(200, {"success": True, "loggedIn": False})
            return
        self._proxy()

    def do_GET(self) -> None:  # noqa: N802
        path = urllib.parse.urlsplit(self.path).path
        if path == "/healthz":
            self._json(200, {"ok": True, "protocol": PROTOCOL})
            return
        if path == "/api/auth/user-info":
            if not self._authorized():
                self._json(401, {"error": "unauthorized", "message": "登录已过期，请重新登录"})
                return
            self._json(200, _user())
            return
        self._proxy()


def main() -> int:
    args = parse_args()
    upstream = args.upstream_base_url.rstrip("/")
    parsed = urllib.parse.urlsplit(upstream)
    if parsed.scheme != "http" or parsed.hostname not in {"127.0.0.1", "localhost"}:
        raise SystemExit("E2E API upstream must be loopback HTTP")
    handler = type("BoundHandler", (Handler,), {})
    handler.upstream, handler.secret = upstream, _secret()
    server = Server((args.host, args.port), handler)
    host, port = server.server_address[:2]
    print(json.dumps({"protocol": PROTOCOL, "ready": True, "baseUrl": f"http://{host}:{port}"}, ensure_ascii=False), flush=True)
    try:
        server.serve_forever(poll_interval=.2)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
