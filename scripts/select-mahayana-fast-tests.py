#!/usr/bin/env python3
"""Select the smallest safe Mahayana fast-test surface for a change.

The selector is deliberately conservative: any shared workspace input or unknown
Mahayana path expands to the complete fast suite. Canonical main/manual runs
always execute the complete suite. Pull requests may use a smaller group set
only for paths whose consumers are explicitly modeled below.
"""

from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

MAHAYANA_ROOT = "third_party/mahayana/mahayana-rs/"
NATIVE_MESSAGING_ROOT = "native/mahayana-messaging/"
SELF_PATHS = {
    ".github/workflows/mahayana-fast-checks.yml",
    "scripts/check-mahayana-source-boundary.py",
    "scripts/select-mahayana-fast-tests.py",
    "scripts/tests/test_select_mahayana_fast_tests.py",
    "tools/fabushi-test/suites.json",
}

GROUPS = (
    "auth_product",
    "kernel_engine",
    "mcp_agent",
    "protocol_bridge",
    "harness",
    "host_ffi",
    "test_driver",
)

# The values are transitive test-group consumers, not merely the changed
# package's own tests. Keep the mapping small and conservative. Anything not
# modeled here falls back to the complete fast suite.
SAFE_PREFIX_GROUPS: tuple[tuple[str, tuple[str, ...]], ...] = (
    (f"{MAHAYANA_ROOT}mahayana-auth/", ("auth_product", "host_ffi")),
    (f"{MAHAYANA_ROOT}mahayana-secrets/", ("auth_product", "host_ffi")),
    (
        f"{MAHAYANA_ROOT}mahayana-kernel/",
        ("kernel_engine", "mcp_agent", "host_ffi"),
    ),
    (
        f"{MAHAYANA_ROOT}mahayana-agent-kernel-bridge/",
        ("kernel_engine", "host_ffi"),
    ),
    (f"{MAHAYANA_ROOT}mahayana-orchestrator/", ("kernel_engine", "host_ffi")),
    (
        f"{MAHAYANA_ROOT}mahayana-workspace-engine/",
        ("kernel_engine", "host_ffi"),
    ),
    (f"{MAHAYANA_ROOT}mahayana-model/", ("kernel_engine", "host_ffi")),
    (f"{MAHAYANA_ROOT}mahayana-native-engine/", ("kernel_engine", "host_ffi")),
    (f"{MAHAYANA_ROOT}mahayana-mcp-runtime/", ("mcp_agent", "host_ffi")),
    (f"{MAHAYANA_ROOT}mahayana-native-agent/", ("mcp_agent", "host_ffi")),
    (
        f"{MAHAYANA_ROOT}mahayana-miniapp-protocol/",
        ("protocol_bridge", "host_ffi"),
    ),
    (
        f"{MAHAYANA_ROOT}mahayana-miniapp-bridge/",
        ("protocol_bridge", "host_ffi"),
    ),
    (
        f"{MAHAYANA_ROOT}mahayana-host-protocol/",
        ("protocol_bridge", "host_ffi"),
    ),
    (f"{MAHAYANA_ROOT}mahayana-harness/", ("harness", "host_ffi")),
    (f"{MAHAYANA_ROOT}mahayana-harness-services/", ("harness", "host_ffi")),
    (f"{MAHAYANA_ROOT}mahayana-harness-advanced/", ("harness",)),
    (f"{MAHAYANA_ROOT}mahayana-harness-adapters/", ("harness",)),
    (f"{MAHAYANA_ROOT}mahayana-harness-agent/", ("harness",)),
    (f"{MAHAYANA_ROOT}mahayana-harness-protocol/", ("harness",)),
    (
        f"{MAHAYANA_ROOT}mahayana-unified-app-host/",
        ("harness", "host_ffi"),
    ),
    (f"{MAHAYANA_ROOT}mahayana-host/", ("host_ffi",)),
    (f"{MAHAYANA_ROOT}mahayana-feature-host/", ("host_ffi",)),
    (f"{MAHAYANA_ROOT}mahayana-ffi/", ("host_ffi",)),
    (f"{MAHAYANA_ROOT}mahayana-test-driver-protocol/", ("test_driver",)),
)

FULL_SUITE_PATHS = {
    f"{MAHAYANA_ROOT}Cargo.toml",
    f"{MAHAYANA_ROOT}Cargo.lock",
    f"{MAHAYANA_ROOT}clippy.toml",
    f"{MAHAYANA_ROOT}rustfmt.toml",
}


@dataclass(frozen=True)
class Selection:
    full_suite: bool
    groups: tuple[str, ...]
    reason: str
    relevant_files: tuple[str, ...]

    @property
    def run_rust(self) -> bool:
        return self.full_suite or bool(self.groups)

    def as_dict(self) -> dict[str, object]:
        return {
            "fullSuite": self.full_suite,
            "runRust": self.run_rust,
            "groups": list(self.groups),
            "reason": self.reason,
            "relevantFiles": list(self.relevant_files),
        }


def normalize_files(files: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    normalized: list[str] = []
    for raw in files:
        value = raw.strip().replace("\\", "/")
        if value.startswith("./"):
            value = value[2:]
        if not value or value in seen:
            continue
        seen.add(value)
        normalized.append(value)
    return sorted(normalized)


def select(event: str, changed_files: Iterable[str]) -> Selection:
    event = event.strip()
    files = normalize_files(changed_files)

    if event != "pull_request":
        return Selection(
            full_suite=True,
            groups=GROUPS,
            reason=f"{event or 'unknown'} requires the canonical full fast suite",
            relevant_files=tuple(files),
        )

    relevant = [
        path
        for path in files
        if path.startswith(MAHAYANA_ROOT)
        or path.startswith(NATIVE_MESSAGING_ROOT)
        or path in SELF_PATHS
    ]
    if not relevant:
        return Selection(
            full_suite=False,
            groups=(),
            reason="no Mahayana fast-gate inputs changed",
            relevant_files=(),
        )

    selected: set[str] = set()
    full_reason: str | None = None

    for path in relevant:
        if path in SELF_PATHS:
            full_reason = f"selector/workflow change requires full fallback: {path}"
            break
        if path.startswith(NATIVE_MESSAGING_ROOT):
            full_reason = f"shared native messaging change requires full fallback: {path}"
            break
        if path in FULL_SUITE_PATHS or path.startswith(f"{MAHAYANA_ROOT}.cargo/"):
            full_reason = f"shared Mahayana workspace input requires full fallback: {path}"
            break

        matched = False
        for prefix, groups in SAFE_PREFIX_GROUPS:
            if path.startswith(prefix):
                selected.update(groups)
                matched = True
                break
        if not matched:
            full_reason = f"unmodeled Mahayana path requires full fallback: {path}"
            break

    if full_reason is not None:
        return Selection(
            full_suite=True,
            groups=GROUPS,
            reason=full_reason,
            relevant_files=tuple(relevant),
        )

    ordered = tuple(group for group in GROUPS if group in selected)
    return Selection(
        full_suite=False,
        groups=ordered,
        reason="affected test groups selected from modeled Mahayana paths",
        relevant_files=tuple(relevant),
    )


def write_github_output(path: Path, selection: Selection) -> None:
    values = {
        "full_suite": str(selection.full_suite).lower(),
        "run_rust": str(selection.run_rust).lower(),
        "selected_groups": ",".join(selection.groups),
        "reason": selection.reason,
    }
    for group in GROUPS:
        values[group] = str(selection.full_suite or group in selection.groups).lower()
    with path.open("a", encoding="utf-8") as handle:
        for key, value in values.items():
            handle.write(f"{key}={value}\n")


def write_summary(path: Path, selection: Selection) -> None:
    rows = [
        "## Mahayana affected fast-test selection",
        "",
        f"- Full suite: `{str(selection.full_suite).lower()}`",
        f"- Run Rust gate: `{str(selection.run_rust).lower()}`",
        f"- Selected groups: `{','.join(selection.groups) or 'none'}`",
        f"- Reason: {selection.reason}",
        f"- Relevant changed files: `{len(selection.relevant_files)}`",
        "",
    ]
    if selection.relevant_files:
        rows.extend(["<details><summary>Relevant paths</summary>", "", "```text"])
        rows.extend(selection.relevant_files)
        rows.extend(["```", "", "</details>", ""])
    with path.open("a", encoding="utf-8") as handle:
        handle.write("\n".join(rows))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--event",
        default=os.environ.get("GITHUB_EVENT_NAME", "pull_request"),
        help="GitHub event name; non-pull_request events force the full suite",
    )
    parser.add_argument(
        "--changed-file",
        action="append",
        default=[],
        help="Changed path; may be repeated. If omitted, newline-delimited paths are read from stdin.",
    )
    parser.add_argument("--github-output", type=Path)
    parser.add_argument("--github-step-summary", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    changed_files = args.changed_file
    if not changed_files:
        import sys

        changed_files = sys.stdin.read().splitlines()
    selection = select(args.event, changed_files)
    print(json.dumps(selection.as_dict(), ensure_ascii=False, sort_keys=True))
    if args.github_output:
        write_github_output(args.github_output, selection)
    if args.github_step_summary:
        write_summary(args.github_step_summary, selection)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
