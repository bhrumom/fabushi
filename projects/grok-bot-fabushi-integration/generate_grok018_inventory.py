#!/usr/bin/env python3
"""Generate the deterministic GBF-106 audit for the pinned Grok Bot 0.18 reconstruction.

This script only reads Git metadata and source text. It never builds either product,
downloads LFS payloads, or copies source from the audited repository into Fabushi.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import pathlib
import re
import subprocess
from collections import Counter


PROJECT = pathlib.Path(__file__).resolve().parent
EVIDENCE = PROJECT / "evidence/GBF-106"
PINNED_COMMIT = "a9f633e09d49a85829b8236331b9e21f7e612634"
PINNED_TREE = "b68f24972427952c4934e4364736fec62661044f"


def git(repo: pathlib.Path, *args: str, binary: bool = False):
    return subprocess.check_output(
        ["git", "-C", str(repo), *args],
        text=not binary,
        errors=None if binary else "surrogateescape",
    )


def classify(path: str) -> str:
    value = path.lower()
    rules = [
        (r"^research-archives/", "upstream-installer-archive"),
        (r"^frontend/src/recovered/features/settings/", "settings-router-ui"),
        (r"^frontend/", "renderer-reconstruction"),
        (r"^source/electron-main/box/local-docker", "local-docker-sandbox"),
        (r"inference-router|provider-session|routed-mcp", "inference-router"),
        (r"usage|billing", "usage-billing"),
        (r"^source/electron-main/", "electron-main"),
        (r"^source/electron-preload/", "electron-preload"),
        (r"^source/node-agent-coordinator/", "coordinator"),
        (r"^source/host/", "agent-host"),
        (r"computer|vnc|local-exec|shell-exec|sandbox", "computer-local-execution"),
        (r"mcp|plugin|marketplace", "mcp-plugin-marketplace"),
        (r"^source/packages/proto/", "generated-protocol"),
        (r"^source/packages/", "recovered-package"),
        (r"^source/shared/", "shared-runtime-contract"),
        (r"^scripts/", "reconstruction-build-tooling"),
        (r"^tests/|\.test\.|\.spec\.", "tests"),
        (r"^docs/|\.md$", "documentation"),
        (r"^\.github/", "ci"),
        (r"^patches/", "third-party-patch"),
        (r"^manifests/", "reconstruction-manifest"),
    ]
    for pattern, domain in rules:
        if re.search(pattern, value):
            return domain
    return "repository-support"


def policy(domain: str) -> tuple[str, str]:
    if domain == "upstream-installer-archive":
        return "REJECT", "binary/LFS artifact; no upstream redistribution grant"
    if domain in {
        "renderer-reconstruction",
        "electron-main",
        "electron-preload",
        "coordinator",
        "agent-host",
        "recovered-package",
        "generated-protocol",
    }:
        return "CLEAN_ROOM_SPEC", "behavior/API reference only; independently implement in Fabushi-owned boundaries"
    if domain in {"reconstruction-build-tooling", "third-party-patch", "reconstruction-manifest"}:
        return "REJECT", "specific to the hybrid reconstruction/package pipeline"
    if domain in {"inference-router", "settings-router-ui", "local-docker-sandbox", "usage-billing"}:
        return "ADAPT_DESIGN", "independently implement observable behavior through Mahayana contracts"
    return "LEARN", "inspect architecture and tests; no verbatim source import"


def entries(repo: pathlib.Path):
    raw = git(repo, "ls-tree", "-r", "-l", "-z", "HEAD", binary=True)
    result = []
    for record in raw.split(b"\0"):
        if not record:
            continue
        meta, encoded_path = record.split(b"\t", 1)
        mode, kind, object_id, size = meta.decode().split()
        path = encoded_path.decode("utf-8", "surrogateescape")
        domain = classify(path)
        decision, reason = policy(domain)
        result.append(
            {
                "mode": mode,
                "type": kind,
                "object": object_id,
                "size": size,
                "path": path,
                "domain": domain,
                "decision": decision,
                "reason": reason,
            }
        )
    return result


def write_tsv(path: pathlib.Path, rows, fields):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def digest(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-repo", type=pathlib.Path, required=True)
    args = parser.parse_args()
    repo = args.source_repo.resolve()
    commit = git(repo, "rev-parse", "HEAD").strip()
    tree = git(repo, "rev-parse", "HEAD^{tree}").strip()
    if commit != PINNED_COMMIT or tree != PINNED_TREE:
        raise SystemExit(f"unexpected source identity: commit={commit} tree={tree}")

    rows = entries(repo)
    manifest = EVIDENCE / "manifest.tsv"
    fields = ["mode", "type", "object", "size", "path", "domain", "decision", "reason"]
    write_tsv(manifest, rows, fields)

    domain_counts = Counter(row["domain"] for row in rows)
    decision_counts = Counter(row["decision"] for row in rows)
    summary = {
        "schema_version": 1,
        "source": "https://github.com/bhrum/grok-bot-0.18-reconstructed",
        "commit": commit,
        "tree": tree,
        "entries": len(rows),
        "manifest_sha256": digest(manifest),
        "domain_counts": dict(sorted(domain_counts.items())),
        "decision_counts": dict(sorted(decision_counts.items())),
        "license_facts": {
            "repository_license_declared": False,
            "upstream_source_license_granted": False,
            "original_installers_present_as_lfs_pointers": True,
            "fabushi_policy": "clean-room behavior/API reimplementation only",
        },
        "validation": {
            "exact_commit": commit == PINNED_COMMIT,
            "exact_tree": tree == PINNED_TREE,
            "all_paths_classified": all(row["domain"] for row in rows),
            "all_paths_have_decision": all(row["decision"] and row["reason"] for row in rows),
            "no_copy_decision": all(row["decision"] != "COPY" for row in rows),
        },
    }
    (EVIDENCE / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
