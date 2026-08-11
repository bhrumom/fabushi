#!/usr/bin/env python3
"""Deterministic Marketplace distribution fixture for the iOS black-box E2E.

This server deliberately replaces only the Marketplace catalog/release transport.
The package itself is built byte-for-byte from the canonical repository plugin,
and the app still downloads it through MahayanaProductClient and installs it
through the production Rust marketplace installer.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import http.server
import io
import json
import os
from pathlib import Path
import socketserver
import tarfile
from typing import Any
import urllib.parse

FIXTURE_PROTOCOL = "fabushi.marketplace.fixture.v1"
DEFAULT_PLUGIN_ID = "global-dharma"
DEFAULT_TITLE = "全球法布施"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plugin-root", required=True)
    parser.add_argument("--package-file", required=True)
    parser.add_argument("--metadata-file", required=True)
    parser.add_argument("--commit-sha", default="unknown")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=18787)
    parser.add_argument("--build-only", action="store_true")
    return parser.parse_args()


def _read_json(path: Path) -> dict[str, Any]:
    decoded = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(decoded, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return decoded


def _validate_canonical_plugin(plugin_root: Path) -> tuple[str, str, str]:
    manifest_path = plugin_root / ".codex-plugin" / "plugin.json"
    mcp_path = plugin_root / ".mcp.json"
    if not manifest_path.is_file() or not mcp_path.is_file():
        raise ValueError("fixture source must contain .codex-plugin/plugin.json and .mcp.json")

    manifest = _read_json(manifest_path)
    plugin_id = str(manifest.get("name", "")).strip()
    version = str(manifest.get("version", "")).strip()
    if plugin_id != DEFAULT_PLUGIN_ID or not version:
        raise ValueError(
            f"fixture must package canonical {DEFAULT_PLUGIN_ID}; got {plugin_id!r}@{version!r}"
        )

    variants = manifest.get("runtimeVariants")
    if not isinstance(variants, list) or not any(
        isinstance(variant, dict)
        and isinstance(variant.get("platforms"), list)
        and "mobile" in variant["platforms"]
        for variant in variants
    ):
        raise ValueError("canonical fixture plugin must declare a mobile runtime variant")

    mcp = _read_json(mcp_path)
    servers = mcp.get("mcpServers")
    if not isinstance(servers, dict) or not servers:
        raise ValueError("canonical fixture plugin must declare MCP servers")
    return plugin_id, version, DEFAULT_TITLE


def _deterministic_archive(plugin_root: Path) -> bytes:
    raw = io.BytesIO()
    with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as gz:
        with tarfile.open(fileobj=gz, mode="w", format=tarfile.PAX_FORMAT) as tar:
            for path in sorted(plugin_root.rglob("*"), key=lambda item: item.as_posix()):
                if path.is_symlink():
                    raise ValueError(f"fixture source must not contain symlinks: {path}")
                relative = path.relative_to(plugin_root).as_posix()
                info = tarfile.TarInfo(relative)
                info.uid = 0
                info.gid = 0
                info.uname = ""
                info.gname = ""
                info.mtime = 0
                if path.is_dir():
                    info.type = tarfile.DIRTYPE
                    info.mode = 0o755
                    info.size = 0
                    tar.addfile(info)
                    continue
                if not path.is_file():
                    raise ValueError(f"unsupported fixture source entry: {path}")
                payload = path.read_bytes()
                info.type = tarfile.REGTYPE
                info.mode = 0o755 if os.access(path, os.X_OK) else 0o644
                info.size = len(payload)
                tar.addfile(info, io.BytesIO(payload))
    return raw.getvalue()


def build_fixture(
    plugin_root: Path,
    package_file: Path,
    metadata_file: Path,
    commit_sha: str,
) -> tuple[bytes, dict[str, Any]]:
    plugin_root = plugin_root.resolve()
    plugin_id, version, title = _validate_canonical_plugin(plugin_root)
    archive = _deterministic_archive(plugin_root)
    digest = hashlib.sha256(archive).hexdigest()
    package_file.parent.mkdir(parents=True, exist_ok=True)
    metadata_file.parent.mkdir(parents=True, exist_ok=True)
    package_file.write_bytes(archive)
    source = {
        "provider": "repository-fixture",
        "repository": "bhrumom/fabushi",
        "commitSha": commit_sha,
        "path": ".agents/plugins/plugins/global-dharma",
    }
    metadata: dict[str, Any] = {
        "protocol": FIXTURE_PROTOCOL,
        "pluginId": plugin_id,
        "version": version,
        "title": title,
        "platforms": ["mobile"],
        "packageSha256": digest,
        "packageSize": len(archive),
        "source": source,
    }
    metadata_file.write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return archive, metadata


class FixtureHTTPServer(http.server.ThreadingHTTPServer):
    # http.server.HTTPServer.server_bind() calls socket.getfqdn(host). On some
    # hosted macOS runners reverse-DNS lookup for 127.0.0.1 can stall long
    # enough to trip the fixture health timeout. The fixture never needs a
    # canonical DNS name, so bind directly and publish the numeric loopback
    # address instead.
    daemon_threads = True

    def server_bind(self) -> None:
        socketserver.TCPServer.server_bind(self)
        host, port = self.server_address[:2]
        self.server_name = str(host)
        self.server_port = int(port)


class FixtureHandler(http.server.BaseHTTPRequestHandler):
    archive: bytes
    metadata: dict[str, Any]
    base_url: str

    def log_message(self, format: str, *args: object) -> None:  # noqa: A002
        print(
            json.dumps(
                {
                    "protocol": FIXTURE_PROTOCOL,
                    "client": self.client_address[0],
                    "request": self.requestline,
                    "message": format % args,
                },
                ensure_ascii=False,
            ),
            flush=True,
        )

    def _json(self, status: int, payload: dict[str, Any]) -> None:
        body = (json.dumps(payload, ensure_ascii=False) + "\n").encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        parsed = urllib.parse.urlsplit(self.path)
        path = parsed.path
        plugin_id = str(self.metadata["pluginId"])
        version = str(self.metadata["version"])
        download_path = f"/v1/marketplace/plugins/{plugin_id}/releases/{version}/download"
        release_path = f"/v1/marketplace/plugins/{plugin_id}/releases/{version}"

        if path == "/healthz":
            self._json(200, {"ok": True, "protocol": FIXTURE_PROTOCOL})
            return

        if path == "/v1/marketplace/plugins":
            query = urllib.parse.parse_qs(parsed.query)
            requested = query.get("q", [""])[0].strip().lower()
            platform = query.get("platform", [""])[0].strip().lower()
            searchable = f"{plugin_id} {self.metadata['title']}".lower()
            visible = (not requested or requested in searchable) and (
                not platform or platform == "mobile"
            )
            plugins: list[dict[str, Any]] = []
            if visible:
                plugins.append(
                    {
                        "pluginId": plugin_id,
                        "displayName": self.metadata["title"],
                        "description": "Canonical 全球法布施 E2E distribution fixture",
                        "latestVersion": version,
                        "platforms": ["mobile"],
                        "packageSha256": self.metadata["packageSha256"],
                        "packageSize": self.metadata["packageSize"],
                        "downloadUrl": f"{self.base_url}{download_path}",
                    }
                )
            self._json(200, {"plugins": plugins})
            return

        if path == release_path:
            self._json(
                200,
                {
                    "schemaVersion": 1,
                    "pluginId": plugin_id,
                    "version": version,
                    "platforms": ["mobile"],
                    "packageSha256": self.metadata["packageSha256"],
                    "packageSize": self.metadata["packageSize"],
                    "downloadUrl": f"{self.base_url}{download_path}",
                    "source": self.metadata["source"],
                    "releaseManifest": {"source": self.metadata["source"]},
                },
            )
            return

        if path == download_path:
            body = self.archive
            self.send_response(200)
            self.send_header("Content-Type", "application/gzip")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        self._json(404, {"error": "not_found", "path": path})


def main() -> int:
    args = parse_args()
    package_file = Path(args.package_file)
    metadata_file = Path(args.metadata_file)
    archive, metadata = build_fixture(
        Path(args.plugin_root),
        package_file,
        metadata_file,
        args.commit_sha,
    )
    if args.build_only:
        print(json.dumps(metadata, ensure_ascii=False), flush=True)
        return 0

    handler = type("BoundFixtureHandler", (FixtureHandler,), {})
    handler.archive = archive
    handler.metadata = metadata
    server = FixtureHTTPServer((args.host, args.port), handler)
    host, port = server.server_address[:2]
    handler.base_url = f"http://{host}:{port}"
    metadata["baseUrl"] = handler.base_url
    metadata_file.write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        json.dumps(
            {
                "protocol": FIXTURE_PROTOCOL,
                "ready": True,
                "baseUrl": handler.base_url,
                "pluginId": metadata["pluginId"],
                "version": metadata["version"],
                "packageSha256": metadata["packageSha256"],
            },
            ensure_ascii=False,
        ),
        flush=True,
    )
    try:
        server.serve_forever(poll_interval=0.2)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
