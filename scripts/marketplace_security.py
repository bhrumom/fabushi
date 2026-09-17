#!/usr/bin/env python3
"""Deterministic, dependency-free security policy for the official Fabushi marketplace."""
from __future__ import annotations

import hashlib
import json
import os
import re
from pathlib import Path, PurePosixPath
from typing import Any
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
INTERNAL = ROOT / ".agents/plugins/marketplace.json"
PUBLIC = ROOT / "frontend/apps/web/public/.well-known/mahayana/marketplace.json"
APPROVALS = ROOT / "frontend/apps/web/public/.well-known/mahayana/marketplace-approvals.json"
PLUGIN_ROOT = ROOT / ".agents/plugins/plugins"

AUDIT_PROTOCOL = "fabushi.marketplace.audit.v1"
APPROVAL_PROTOCOL = "fabushi.marketplace.approvals.v1"
POLICY_VERSION = 1
ID_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
VERSION_RE = re.compile(r"^[0-9A-Za-z][0-9A-Za-z.+_-]{0,63}$")

TEXT_SCAN_SUFFIXES = {
    ".c", ".cc", ".cpp", ".cs", ".go", ".h", ".hpp", ".html", ".java", ".js", ".json",
    ".jsx", ".kt", ".kts", ".mjs", ".cjs", ".php", ".pl", ".ps1", ".py", ".rb", ".rs",
    ".sh", ".swift", ".toml", ".ts", ".tsx", ".yaml", ".yml", ".zsh",
}
DANGER_SCAN_SUFFIXES = {
    ".js", ".jsx", ".mjs", ".cjs", ".ps1", ".py", ".rb", ".rs", ".sh", ".ts", ".tsx", ".zsh",
}
SECRET_FILENAMES = {
    ".env", ".npmrc", ".pypirc", "credentials", "credentials.json", "id_dsa", "id_ecdsa",
    "id_ed25519", "id_rsa", "service-account.json",
}
SECRET_PATTERNS = (
    ("PRIVATE_KEY", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    ("GITHUB_TOKEN", re.compile(r"\b(?:ghp|github_pat)_[A-Za-z0-9_]{20,}\b")),
    ("AWS_ACCESS_KEY", re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b")),
    ("OPENAI_KEY", re.compile(r"\bsk-(?:proj-)?[A-Za-z0-9_-]{24,}\b")),
)
DANGEROUS_PATTERNS = (
    (
        "REMOTE_PIPE_SHELL",
        re.compile(r"(?:curl|wget)\b[^\n|]{0,500}\|\s*(?:sudo\s+)?(?:bash|sh|zsh|python(?:3)?|node|powershell|pwsh)\b", re.I),
    ),
    (
        "POWERSHELL_REMOTE_EXEC",
        re.compile(r"\b(?:iex|invoke-expression)\b[^\n]{0,500}\b(?:downloadstring|invoke-webrequest|iwr|irm|invoke-restmethod)\b", re.I),
    ),
    (
        "REMOTE_DYNAMIC_EVAL",
        re.compile(r"(?:eval|new\s+Function)\s*\([^\n]{0,500}(?:fetch\s*\(|https?://)", re.I),
    ),
    (
        "DECODE_PIPE_SHELL",
        re.compile(r"(?:base64\s+(?:-d|--decode)|certutil\b[^\n]{0,100}-decode)[^\n|]{0,500}\|\s*(?:bash|sh|zsh|powershell|pwsh)\b", re.I),
    ),
)


def load_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def canonical_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def finding(code: str, message: str, *, path: str | None = None, severity: str = "HIGH") -> dict[str, Any]:
    item: dict[str, Any] = {"severity": severity, "code": code, "message": message}
    if path:
        item["path"] = path
    return item


def safe_relative_path(value: str) -> bool:
    if not value or "\x00" in value:
        return False
    normalized = value.replace("\\", "/")
    candidate = PurePosixPath(normalized)
    if candidate.is_absolute() or ".." in candidate.parts:
        return False
    if re.match(r"^[A-Za-z]:/", normalized):
        return False
    return True


def _iter_plugin_files(plugin_dir: Path):
    for path in sorted(plugin_dir.rglob("*"), key=lambda p: p.relative_to(plugin_dir).as_posix()):
        yield path


def plugin_digest(plugin_dir: Path) -> tuple[str, int, int, list[dict[str, Any]]]:
    digest = hashlib.sha256()
    file_count = 0
    byte_count = 0
    findings: list[dict[str, Any]] = []
    for path in _iter_plugin_files(plugin_dir):
        rel = path.relative_to(plugin_dir).as_posix()
        if path.is_symlink():
            findings.append(finding("SYMLINK_FORBIDDEN", "plugin packages must not contain symlinks", path=rel, severity="CRITICAL"))
            continue
        if not path.is_file():
            continue
        data = path.read_bytes()
        encoded = rel.encode("utf-8")
        digest.update(len(encoded).to_bytes(8, "big"))
        digest.update(encoded)
        digest.update(len(data).to_bytes(8, "big"))
        digest.update(data)
        file_count += 1
        byte_count += len(data)
    return digest.hexdigest(), file_count, byte_count, findings


def _scan_file(plugin_dir: Path, path: Path) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    rel = path.relative_to(plugin_dir).as_posix()
    basename = path.name.lower()
    if basename in SECRET_FILENAMES or (basename.startswith(".env.") and basename not in {".env.example", ".env.sample", ".env.template"}):
        findings.append(finding("SECRET_FILE_FORBIDDEN", "credential-bearing files are not allowed in marketplace plugins", path=rel, severity="CRITICAL"))

    if path.suffix.lower() not in TEXT_SCAN_SUFFIXES and basename not in {"dockerfile", "makefile"}:
        return findings
    if path.stat().st_size > 2 * 1024 * 1024:
        return findings
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return findings

    for code, pattern in SECRET_PATTERNS:
        if pattern.search(text):
            findings.append(finding(code, "high-confidence embedded credential material detected", path=rel, severity="CRITICAL"))

    if path.suffix.lower() in DANGER_SCAN_SUFFIXES or os.access(path, os.X_OK):
        for code, pattern in DANGEROUS_PATTERNS:
            if pattern.search(text):
                findings.append(finding(code, "unsafe remote/decode-to-execution pattern detected", path=rel, severity="CRITICAL"))
    return findings


def _validate_url(url: str, *, field: str, allow_local_http: bool = True) -> list[dict[str, Any]]:
    parsed = urlparse(url)
    if parsed.scheme == "https" and parsed.hostname:
        return []
    if allow_local_http and parsed.scheme == "http" and parsed.hostname in {"localhost", "127.0.0.1", "::1"}:
        return []
    return [finding("UNSAFE_URL", f"{field} must use HTTPS (HTTP is allowed only for localhost)")]


def _manifest_findings(plugin_id: str, internal_entry: dict[str, Any], plugin_dir: Path) -> tuple[dict[str, Any] | None, list[dict[str, Any]]]:
    findings: list[dict[str, Any]] = []
    required = [
        plugin_dir / ".codex-plugin/plugin.json",
        plugin_dir / ".mahayana/plugin.json",
        plugin_dir / ".mcp.json",
    ]
    for required_path in required:
        if not required_path.is_file():
            findings.append(finding("MISSING_DESCRIPTOR", f"missing required descriptor {required_path.relative_to(plugin_dir)}", severity="CRITICAL"))
    if findings:
        return None, findings

    try:
        codex = load_json(required[0])
        mahayana = load_json(required[1])
        mcp = load_json(required[2])
    except (OSError, ValueError, TypeError) as exc:
        return None, [finding("INVALID_DESCRIPTOR", f"failed to parse plugin descriptor: {exc}", severity="CRITICAL")]

    expected_version = str(internal_entry.get("version", ""))
    if codex.get("name") != plugin_id:
        findings.append(finding("PLUGIN_ID_MISMATCH", "Codex manifest name does not match marketplace id", path=".codex-plugin/plugin.json", severity="CRITICAL"))
    if str(codex.get("version", "")) != expected_version:
        findings.append(finding("PLUGIN_VERSION_MISMATCH", "Codex manifest version does not match marketplace version", path=".codex-plugin/plugin.json", severity="CRITICAL"))
    if not VERSION_RE.fullmatch(expected_version):
        findings.append(finding("INVALID_VERSION", "marketplace version is invalid", severity="CRITICAL"))
    if mahayana.get("schemaVersion") != 1:
        findings.append(finding("MAHAYANA_SCHEMA", "Mahayana plugin descriptor must use schemaVersion 1", path=".mahayana/plugin.json", severity="CRITICAL"))
    if not isinstance(mcp.get("mcpServers"), dict) or not mcp.get("mcpServers"):
        findings.append(finding("MCP_SERVERS_REQUIRED", "plugin must declare at least one MCP server", path=".mcp.json", severity="CRITICAL"))

    runtime = mahayana.get("runtime") if isinstance(mahayana.get("runtime"), dict) else {}
    for runtime_name, descriptor in runtime.items():
        if not isinstance(descriptor, dict):
            findings.append(finding("INVALID_RUNTIME", f"runtime {runtime_name} must be an object", path=".mahayana/plugin.json", severity="CRITICAL"))
            continue
        for key in ("executable", "module"):
            value = descriptor.get(key)
            if value is not None and (not isinstance(value, str) or not safe_relative_path(value)):
                findings.append(finding("UNSAFE_RUNTIME_PATH", f"runtime {runtime_name}.{key} must be a relative path without traversal", path=".mahayana/plugin.json", severity="CRITICAL"))

    for server_name, server in (mcp.get("mcpServers") or {}).items():
        if not isinstance(server, dict):
            findings.append(finding("INVALID_MCP_SERVER", f"MCP server {server_name} must be an object", path=".mcp.json", severity="CRITICAL"))
            continue
        command = server.get("command")
        if command is not None and (not isinstance(command, str) or not safe_relative_path(command)):
            findings.append(finding("UNSAFE_MCP_COMMAND", f"MCP server {server_name} command must not be absolute or traverse directories", path=".mcp.json", severity="CRITICAL"))
        cwd = server.get("cwd")
        if cwd is not None and (not isinstance(cwd, str) or not safe_relative_path(cwd)):
            findings.append(finding("UNSAFE_MCP_CWD", f"MCP server {server_name} cwd must be a relative path without traversal", path=".mcp.json", severity="CRITICAL"))
        url = server.get("url")
        if url is not None:
            if not isinstance(url, str):
                findings.append(finding("INVALID_MCP_URL", f"MCP server {server_name} url must be a string", path=".mcp.json", severity="CRITICAL"))
            else:
                findings.extend({**item, "path": ".mcp.json"} for item in _validate_url(url, field=f"MCP server {server_name} URL"))

    return codex, findings


def load_approvals() -> dict[str, dict[str, Any]]:
    if not APPROVALS.exists():
        return {}
    data = load_json(APPROVALS)
    if data.get("protocol") != APPROVAL_PROTOCOL or data.get("schemaVersion") != 1:
        raise ValueError("unsupported marketplace approval ledger")
    plugins = data.get("plugins")
    if not isinstance(plugins, list):
        raise ValueError("marketplace approval ledger plugins must be an array")
    return {str(item.get("id")): item for item in plugins if isinstance(item, dict)}


def audit_official_plugins(*, source_sha: str = "unknown") -> dict[str, Any]:
    internal = load_json(INTERNAL)
    registry_plugins = internal.get("plugins")
    if internal.get("schemaVersion") != 1 or not isinstance(registry_plugins, list):
        raise ValueError("unsupported internal marketplace registry")

    global_findings: list[dict[str, Any]] = []
    registry: dict[str, dict[str, Any]] = {}
    for entry in registry_plugins:
        plugin_id = str(entry.get("name", "")) if isinstance(entry, dict) else ""
        if not ID_RE.fullmatch(plugin_id):
            global_findings.append(finding("INVALID_PLUGIN_ID", f"invalid marketplace plugin id {plugin_id!r}", severity="CRITICAL"))
            continue
        if plugin_id in registry:
            global_findings.append(finding("DUPLICATE_PLUGIN_ID", f"duplicate marketplace plugin id {plugin_id}", severity="CRITICAL"))
            continue
        registry[plugin_id] = entry

    disk_ids = {path.name for path in PLUGIN_ROOT.iterdir() if path.is_dir()}
    registry_ids = set(registry)
    for plugin_id in sorted(registry_ids - disk_ids):
        global_findings.append(finding("MISSING_PLUGIN_DIRECTORY", f"registered plugin {plugin_id} has no plugin directory", severity="CRITICAL"))
    for plugin_id in sorted(disk_ids - registry_ids):
        global_findings.append(finding("UNREGISTERED_PLUGIN_DIRECTORY", f"plugin directory {plugin_id} is not registered", severity="CRITICAL"))

    approvals = load_approvals()
    reports: list[dict[str, Any]] = []
    for plugin_id in sorted(registry_ids & disk_ids):
        entry = registry[plugin_id]
        plugin_dir = PLUGIN_ROOT / plugin_id
        digest, file_count, byte_count, findings = plugin_digest(plugin_dir)
        codex, manifest_findings = _manifest_findings(plugin_id, entry, plugin_dir)
        findings.extend(manifest_findings)
        for path in _iter_plugin_files(plugin_dir):
            if path.is_file() and not path.is_symlink():
                findings.extend(_scan_file(plugin_dir, path))

        approval = approvals.get(plugin_id)
        if approval and str(approval.get("version")) == str(entry.get("version")) and approval.get("digest") != digest:
            findings.append(finding(
                "APPROVED_VERSION_MUTATED",
                "an already-approved plugin version changed digest; bump the plugin version before publishing",
                severity="CRITICAL",
            ))
        reports.append({
            "id": plugin_id,
            "version": str(entry.get("version", "")),
            "digest": digest,
            "fileCount": file_count,
            "byteCount": byte_count,
            "decision": "rejected" if findings else "approved",
            "findings": findings,
            "metadata": {
                "displayName": ((codex or {}).get("interface") or {}).get("displayName") if isinstance((codex or {}).get("interface"), dict) else None,
            },
        })

    decision = "rejected" if global_findings or any(report["decision"] != "approved" for report in reports) else "approved"
    return {
        "schemaVersion": 1,
        "protocol": AUDIT_PROTOCOL,
        "policyVersion": POLICY_VERSION,
        "sourceSha": source_sha,
        "decision": decision,
        "summary": {
            "pluginCount": len(reports),
            "approved": sum(1 for report in reports if report["decision"] == "approved"),
            "rejected": sum(1 for report in reports if report["decision"] != "approved"),
            "globalFindingCount": len(global_findings),
        },
        "findings": global_findings,
        "plugins": reports,
    }


def fail_if_rejected(report: dict[str, Any]) -> None:
    if report.get("decision") == "approved":
        return
    messages = []
    for item in report.get("findings", []):
        messages.append(f"global:{item.get('code')}:{item.get('message')}")
    for plugin in report.get("plugins", []):
        for item in plugin.get("findings", []):
            messages.append(f"{plugin.get('id')}:{item.get('code')}:{item.get('path', '')}:{item.get('message')}")
    raise RuntimeError("marketplace security review rejected:\n" + "\n".join(messages))
