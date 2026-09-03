#!/usr/bin/env python3
"""Fail CI when vendor implementation types leak into Mahayana-owned product paths."""

from __future__ import annotations

import pathlib
import re
import sys
import tomllib
from collections import deque
from typing import Any

ROOT = pathlib.Path(__file__).resolve().parents[1]
MAHAYANA = ROOT / "third_party" / "mahayana" / "mahayana-rs"
SOURCE_LOCK = MAHAYANA / "SOURCES.lock"
WORKSPACE_MANIFEST = MAHAYANA / "Cargo.toml"

PRODUCT_CRATES = (
    "mahayana-core",
    "mahayana-agent",
    "mahayana-auth",
    "mahayana-conversation",
    "mahayana-runtime",
    "mahayana-tool-host",
    "mahayana-kernel",
    "mahayana-orchestrator",
    "mahayana-workspace-engine",
    "mahayana-model",
    "mahayana-mcp-runtime",
    "mahayana-native-agent",
    "mahayana-native-engine",
    "mahayana-computer",
    "mahayana-platform-core",
    "mahayana-plugin-runtime",
    "mahayana-js-runtime",
    "mahayana-secrets",
)

# These packages represent the default/native product surfaces whose dependency
# closure must remain Mahayana-owned. Compatibility adapters may exist in the
# workspace, but they must not be reachable from these default roots.
DEFAULT_NATIVE_ROOTS = (
    "mahayana-native-engine",
    "mahayana-native-agent",
    "mahayana-host",
    "mahayana-ffi",
    "mahayana-feature-host",
    "mahayana-platform-client",
    "mahayana-cli",
    "mahayana-app-host",
    "mahayana-app-host-desktop",
    "mahayana-app-host-mobile",
    "mahayana-unified-app-host",
    "mahayana-web",
)

FORBIDDEN_SOURCE_PATTERNS = (
    re.compile(r"\buse\s+codex_[A-Za-z0-9_:]*"),
    re.compile(r"\bextern\s+crate\s+codex_[A-Za-z0-9_]*"),
    re.compile(r"\buse\s+xai_[A-Za-z0-9_:]*"),
    re.compile(r"\bextern\s+crate\s+xai_[A-Za-z0-9_]*"),
)

FORBIDDEN_MANIFEST_PATTERNS = (
    re.compile(r"^\s*codex-[A-Za-z0-9_-]+\s*=", re.MULTILINE),
    re.compile(r"^\s*xai-[A-Za-z0-9_-]+\s*=", re.MULTILINE),
)

VENDOR_PACKAGE_PREFIXES = ("codex-", "xai-", "grok-")
VENDOR_ADAPTER_PACKAGES = {"mahayana-agent-codex"}

REQUIRED_LOCK_VALUES = (
    "repository=https://github.com/openai/codex.git",
    "repository=https://github.com/xai-org/grok-build.git",
    "license=Apache-2.0",
    "canonical_agent_provider=mahayana-agent",
    "canonical_agent_conversation=mahayana-ai:agent:assistant",
)

PRODUCT_CLIENT = MAHAYANA / "mahayana-product"
PRODUCT_CLIENT_REQUIRED_ALIASES = (
    'codex-login = { package = "mahayana-auth", path = "../mahayana-auth" }',
    'codex-secrets = { package = "mahayana-secrets", path = "../mahayana-secrets" }',
)
PRODUCT_CLIENT_ALLOWED_LEGACY_IMPORTS = {
    "use codex_login::token_data::parse_jwt_expiration;",
    "use codex_secrets::LocalSecretsNamespace;",
    "use codex_secrets::SecretName;",
    "use codex_secrets::SecretScope;",
    "use codex_secrets::SecretsBackendKind;",
    "use codex_secrets::SecretsManager;",
}


def fail(message: str) -> None:
    print(f"mahayana-source-boundary: {message}", file=sys.stderr)
    raise SystemExit(1)


def read_toml(path: pathlib.Path) -> dict[str, Any]:
    with path.open("rb") as handle:
        return tomllib.load(handle)


def check_source_lock() -> None:
    if not SOURCE_LOCK.is_file():
        fail(f"missing provenance lock: {SOURCE_LOCK.relative_to(ROOT)}")
    text = SOURCE_LOCK.read_text(encoding="utf-8")
    for value in REQUIRED_LOCK_VALUES:
        if value not in text:
            fail(f"SOURCES.lock missing required value: {value}")
    commits = re.findall(r"reviewed_commit=([0-9a-f]+)", text)
    if len(commits) < 2 or any(len(commit) != 40 for commit in commits):
        fail("SOURCES.lock must pin full 40-character reviewed commits")


def check_product_crate(crate: str) -> list[str]:
    crate_root = MAHAYANA / crate
    if not crate_root.is_dir():
        return [f"missing product crate: {crate}"]
    violations: list[str] = []
    manifest = crate_root / "Cargo.toml"
    if manifest.is_file():
        text = manifest.read_text(encoding="utf-8")
        for pattern in FORBIDDEN_MANIFEST_PATTERNS:
            for match in pattern.finditer(text):
                line = text.count("\n", 0, match.start()) + 1
                violations.append(
                    f"{manifest.relative_to(ROOT)}:{line}: vendor dependency belongs in an adapter"
                )
    src = crate_root / "src"
    if src.is_dir():
        for path in sorted(src.rglob("*.rs")):
            text = path.read_text(encoding="utf-8")
            for pattern in FORBIDDEN_SOURCE_PATTERNS:
                for match in pattern.finditer(text):
                    line = text.count("\n", 0, match.start()) + 1
                    violations.append(
                        f"{path.relative_to(ROOT)}:{line}: vendor type import belongs in an adapter"
                    )
    return violations


def check_product_client_native_auth_boundary() -> list[str]:
    """Allow only temporary source aliases that resolve to Mahayana packages."""
    violations: list[str] = []
    manifest = PRODUCT_CLIENT / "Cargo.toml"
    source = PRODUCT_CLIENT / "src" / "lib.rs"
    if not manifest.is_file() or not source.is_file():
        return ["mahayana-product manifest/source is missing"]

    manifest_text = manifest.read_text(encoding="utf-8")
    if "../codex-rs" in manifest_text or "../grok" in manifest_text:
        violations.append(
            f"{manifest.relative_to(ROOT)}: product client must not depend on upstream source paths"
        )
    for required in PRODUCT_CLIENT_REQUIRED_ALIASES:
        if required not in manifest_text:
            violations.append(
                f"{manifest.relative_to(ROOT)}: missing Mahayana-owned compatibility alias: {required}"
            )

    source_text = source.read_text(encoding="utf-8")
    vendor_imports = {
        line.strip()
        for line in source_text.splitlines()
        if line.strip().startswith(("use codex_", "use xai_"))
    }
    unexpected = sorted(vendor_imports - PRODUCT_CLIENT_ALLOWED_LEGACY_IMPORTS)
    if unexpected:
        violations.append(
            f"{source.relative_to(ROOT)}: unexpected vendor-style imports: {', '.join(unexpected)}"
        )
    return violations


def check_adapter_exists() -> None:
    codex_adapter = MAHAYANA / "mahayana-agent-codex"
    if not codex_adapter.is_dir():
        fail("expected Codex compatibility adapter boundary is missing")
    implementation = codex_adapter / "src" / "implementation.rs"
    if not implementation.is_file():
        fail("Codex adapter implementation boundary is missing")


def package_manifests() -> dict[str, pathlib.Path]:
    packages: dict[str, pathlib.Path] = {}
    for manifest in sorted(MAHAYANA.rglob("Cargo.toml")):
        if "target" in manifest.parts:
            continue
        data = read_toml(manifest)
        package = data.get("package")
        if not isinstance(package, dict):
            continue
        name = package.get("name")
        if isinstance(name, str):
            packages[name] = manifest
    return packages


def enabled_default_optional_dependencies(data: dict[str, Any]) -> set[str]:
    features = data.get("features", {})
    if not isinstance(features, dict):
        return set()
    pending = list(features.get("default", []))
    visited: set[str] = set()
    enabled: set[str] = set()
    while pending:
        item = pending.pop()
        if not isinstance(item, str):
            continue
        if item.startswith("dep:"):
            enabled.add(item[4:])
            continue
        dependency = item.split("/", 1)[0].rstrip("?")
        if "/" in item:
            enabled.add(dependency)
            continue
        if item in visited:
            continue
        visited.add(item)
        nested = features.get(item)
        if isinstance(nested, list):
            pending.extend(nested)
        else:
            # Cargo exposes an implicit feature for an optional dependency unless
            # the dependency is referenced through dep:<name>.
            enabled.add(item)
    return enabled


def dependency_tables(data: dict[str, Any]) -> list[dict[str, Any]]:
    tables: list[dict[str, Any]] = []
    for key in ("dependencies", "build-dependencies"):
        table = data.get(key)
        if isinstance(table, dict):
            tables.append(table)
    targets = data.get("target", {})
    if isinstance(targets, dict):
        for target in targets.values():
            if not isinstance(target, dict):
                continue
            for key in ("dependencies", "build-dependencies"):
                table = target.get(key)
                if isinstance(table, dict):
                    tables.append(table)
    return tables


def resolve_dependency(
    name: str,
    spec: Any,
    workspace_dependencies: dict[str, Any],
) -> tuple[str, bool]:
    resolved = spec
    if isinstance(spec, dict) and spec.get("workspace") is True:
        workspace_spec = workspace_dependencies.get(name)
        if workspace_spec is not None:
            resolved = workspace_spec
    optional = isinstance(spec, dict) and bool(spec.get("optional", False))
    package = name
    if isinstance(resolved, dict):
        candidate = resolved.get("package")
        if isinstance(candidate, str):
            package = candidate
    if isinstance(spec, dict):
        candidate = spec.get("package")
        if isinstance(candidate, str):
            package = candidate
    return package, optional


def check_default_native_dependency_graph() -> list[str]:
    packages = package_manifests()
    workspace = read_toml(WORKSPACE_MANIFEST)
    workspace_dependencies = (
        workspace.get("workspace", {}).get("dependencies", {})
        if isinstance(workspace.get("workspace"), dict)
        else {}
    )
    if not isinstance(workspace_dependencies, dict):
        workspace_dependencies = {}

    violations: list[str] = []
    for root in DEFAULT_NATIVE_ROOTS:
        if root not in packages:
            violations.append(f"default native root package is missing: {root}")
            continue
        pending: deque[tuple[str, tuple[str, ...]]] = deque([(root, (root,))])
        visited: set[str] = set()
        while pending:
            package, chain = pending.popleft()
            if package in visited:
                continue
            visited.add(package)
            manifest = packages.get(package)
            if manifest is None:
                continue
            data = read_toml(manifest)
            enabled_optional = enabled_default_optional_dependencies(data)
            for table in dependency_tables(data):
                for dependency_name, spec in table.items():
                    target_package, optional = resolve_dependency(
                        dependency_name, spec, workspace_dependencies
                    )
                    if optional and dependency_name not in enabled_optional:
                        continue
                    dependency_chain = (*chain, target_package)
                    if target_package in VENDOR_ADAPTER_PACKAGES or target_package.startswith(
                        VENDOR_PACKAGE_PREFIXES
                    ):
                        violations.append(
                            "default native dependency graph reaches vendor implementation: "
                            + " -> ".join(dependency_chain)
                        )
                        continue
                    if target_package in packages and target_package not in visited:
                        pending.append((target_package, dependency_chain))
    return sorted(set(violations))


def main() -> None:
    check_source_lock()
    check_adapter_exists()
    violations: list[str] = []
    for crate in PRODUCT_CRATES:
        violations.extend(check_product_crate(crate))
    violations.extend(check_product_client_native_auth_boundary())
    violations.extend(check_default_native_dependency_graph())
    if violations:
        print("Mahayana vendor-boundary violations:", file=sys.stderr)
        for violation in violations:
            print(f"- {violation}", file=sys.stderr)
        raise SystemExit(1)
    print(
        "Mahayana source boundary OK: native crates are provider-neutral; "
        "the default product dependency graph is vendor-independent; "
        "product auth/secrets resolve only to Mahayana-owned packages; "
        "vendor implementations remain adapter-only."
    )


if __name__ == "__main__":
    main()
