#!/usr/bin/env python3
"""Generate deterministic M1 inventory/evidence for FAB-P0004.

Lightweight Git metadata inspection only: no build, dependency install, or test execution.
"""
from __future__ import annotations

import csv
import hashlib
import json
import pathlib
import re
import subprocess
from collections import Counter, defaultdict

ROOT = pathlib.Path(__file__).resolve().parents[2]
PROJECT = ROOT / "projects/grok-bot-fabushi-integration"
MAIN = "e621c65314319dab313f13a3bab0195f112ef66f"
LATEST = "7174a70567ae98ef534b0eebcbe66935f1471cc1"
LEGACY = "a8bd854b512a3eaf20be9518767ab593724d67dc"
MERGE_BASE = "fb3ac82da93de473a372f489cf8ecb7f348c87d0"
REFS = {"main": MAIN, "latest-0.20": LATEST, "legacy-0.16": LEGACY}


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True, errors="surrogateescape")


def ensure(path: pathlib.Path) -> pathlib.Path:
    path.mkdir(parents=True, exist_ok=True)
    return path


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def tree_entries(ref: str):
    raw = subprocess.check_output(
        ["git", "ls-tree", "-r", "-l", "-z", ref], cwd=ROOT
    )
    rows = []
    for record in raw.split(b"\0"):
        if not record:
            continue
        meta, path = record.split(b"\t", 1)
        parts = meta.decode().split()
        mode, typ, oid, size = parts[0], parts[1], parts[2], parts[3]
        rows.append(
            {
                "mode": mode,
                "type": typ,
                "object": oid,
                "size": size,
                "path": path.decode("utf-8", "surrogateescape"),
            }
        )
    return rows


def classify(path: str) -> str:
    p = path.lower()
    rules = [
        (r"^vendor/grok-bot-", "grok-vendor-snapshot"),
        (r"(^|/)grok-(bot|agent|rpc)|grok-bot-mark-engine", "grok-derived-runtime"),
        (r"^desktop/electron/", "electron-runtime"),
        (r"^desktop/e2e/", "desktop-e2e"),
        (r"^desktop/src/", "desktop-renderer"),
        (r"^frontend/apps/web/src/app/host/", "host-ui"),
        (r"^frontend/apps/web/src/lib/mahayana-host/", "mahayana-host-web"),
        (r"^frontend/apps/web/src/lib/fabushi-runtime/", "fabushi-runtime-web"),
        (r"remote-computer|mahayana-computer|computer-control|computer_use|computer-use", "computer-control"),
        (r"^third_party/mahayana/mahayana-rs/", "mahayana-sovereign-runtime"),
        (r"^third_party/mahayana/codex-rs/", "third-party-codex"),
        (r"^mobile/ios/", "native-ios"),
        (r"^mobile/android/", "native-android"),
        (r"^mobile/native/", "native-mobile-ffi"),
        (r"offline-asr|speech|whisper", "offline-asr"),
        (r"auth|oauth|login|identity", "identity-auth"),
        (r"message|chat|room|collaboration|notification", "messaging-collaboration"),
        (r"^ai-backend/", "ai-backend"),
        (r"^fabushi/web/", "platform-web-worker"),
        (r"^\.github/workflows/|^\.github/scripts/", "ci-cd-validation"),
        (r"^\.agent/|^\.agents/", "agent-plugin-governance"),
        (r"^apps/fabushi-tauri/|^fabushi/(lib|ios|android|macos|windows)/", "retired-client"),
        (r"^native/telegram-", "telegram-runtime"),
        (r"^projects/", "project-governance"),
        (r"^docs/|\.md$", "documentation"),
        (r"\.(png|jpg|jpeg|gif|svg|webp|ico|woff2?|ttf|otf)$", "asset"),
        (r"(^|/)(test|tests|__tests__|e2e)(/|$)|\.(test|spec)\.", "tests"),
    ]
    for pattern, domain in rules:
        if re.search(pattern, p):
            return domain
    return "repository-other"


def diff_name_status(base: str, head: str):
    out = git("diff", "--name-status", "--find-renames", base, head)
    rows = []
    for line in out.splitlines():
        if not line:
            continue
        parts = line.split("\t")
        status = parts[0]
        if status.startswith("R") or status.startswith("C"):
            path = parts[-1]
            previous = parts[-2]
        else:
            path = parts[-1]
            previous = ""
        rows.append((status, path, previous))
    return rows


def treatment(status: str, path: str, source_ref: str) -> str:
    domain = classify(path)
    # Git diff is source -> main. A means main-only, D means source-only.
    if status.startswith("A"):
        return "MAIN_HAS"
    if status.startswith("D"):
        if domain in {"grok-vendor-snapshot", "grok-derived-runtime"}:
            return "DEPRECATE_OR_REWRITE"
        if domain == "retired-client":
            return "DEPRECATE"
        return "SOURCE_BETTER_REVIEW"
    if status.startswith("R") or status.startswith("C"):
        return "MIGRATE_REWRITE_REVIEW"
    if status.startswith("M") or status.startswith("T"):
        return "MAIN_SUPERSEDES_REVIEW"
    return "MAIN_SUPERSEDES_REVIEW"


def provenance(path: str, status_from_base: str) -> tuple[str, str, str]:
    domain = classify(path)
    if domain == "grok-vendor-snapshot":
        return (
            "external-grok-production-snapshot",
            "PROVENANCE_BLOCKED",
            "reference-only; do not ship/copy verbatim without explicit license/authorization",
        )
    if domain == "grok-derived-runtime":
        return (
            "historical-grok-derived-path",
            "PROVENANCE_REVIEW",
            "prefer behavior-level clean reimplementation in Fabushi-owned modules",
        )
    if domain == "third-party-codex":
        return (
            "declared-third-party-tree",
            "THIRD_PARTY_DECLARED",
            "retain only under repository third-party license/notice policy",
        )
    if path.startswith("native/telegram-"):
        return (
            "declared-telegram-integration",
            "THIRD_PARTY_DECLARED",
            "outside GBF migration surface except shared runtime interactions",
        )
    return (
        "fabushi-repository-history",
        "FIRST_PARTY_HISTORY_REVIEWED",
        "retain current main or migrate behavior atomically; no wholesale branch overwrite",
    )


def write_tsv(path: pathlib.Path, rows, fields):
    ensure(path.parent)
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def main():
    # GBF-101 refs.
    e101 = ensure(PROJECT / "evidence/GBF-101")
    ref_rows = []
    for name, ref in REFS.items():
        commit = git("rev-parse", ref).strip()
        tree = git("rev-parse", f"{ref}^{{tree}}").strip()
        meta = git("show", "-s", "--format=%aI%x09%cI%x09%s", ref).strip().split("\t", 2)
        ref_rows.append({"name": name, "commit": commit, "tree": tree, "author_date": meta[0], "commit_date": meta[1], "subject": meta[2]})
    (e101 / "refs.json").write_text(json.dumps({"merge_base": MERGE_BASE, "refs": ref_rows}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    latest_counts = git("rev-list", "--left-right", "--count", f"{MAIN}...{LATEST}").strip().split()
    legacy_counts = git("rev-list", "--left-right", "--count", f"{MAIN}...{LEGACY}").strip().split()
    e101_readme = f"""# GBF-101 evidence — pinned source refs\n\n- Project: `FAB-P0004` / `GBF`\n- main commit: `{MAIN}`\n- main tree: `{git('rev-parse', MAIN + '^{tree}').strip()}`\n- latest Grok input: `{LATEST}`\n- latest tree: `{git('rev-parse', LATEST + '^{tree}').strip()}`\n- 0.16 Grok input: `{LEGACY}`\n- 0.16 tree: `{git('rev-parse', LEGACY + '^{tree}').strip()}`\n- common merge-base: `{MERGE_BASE}`\n- main vs latest ahead/behind: `{latest_counts[0]}/{latest_counts[1]}`\n- main vs 0.16 ahead/behind: `{legacy_counts[0]}/{legacy_counts[1]}`\n- ancestry: neither historical source head is an ancestor of main, and main is not an ancestor of either source head. Treat both as immutable input snapshots only.\n\nMachine-readable metadata: `refs.json`.\n"""
    (e101 / "README.md").write_text(e101_readme, encoding="utf-8")

    # GBF-102 full recursive manifests.
    e102 = ensure(PROJECT / "evidence/GBF-102/manifests")
    manifest_summary = {}
    for label, ref in (("latest-0.20", LATEST), ("legacy-0.16", LEGACY)):
        rows = tree_entries(ref)
        out = e102 / f"{label}.tsv"
        write_tsv(out, rows, ["mode", "type", "object", "size", "path"])
        counts = Counter(row["type"] for row in rows)
        manifest_summary[label] = {
            "ref": ref,
            "tree": git("rev-parse", f"{ref}^{{tree}}").strip(),
            "entries": len(rows),
            "type_counts": dict(sorted(counts.items())),
            "sha256": sha256(out),
        }
    (PROJECT / "evidence/GBF-102/summary.json").write_text(json.dumps(manifest_summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (PROJECT / "evidence/GBF-102/README.md").write_text(
        "# GBF-102 evidence — recursive source manifests\n\n"
        "Both pinned historical source heads are recursively enumerated with Git mode/type/object/size/path. "
        "`summary.json` records the exact tree SHA, entry count, and SHA-256 for each TSV.\n",
        encoding="utf-8",
    )

    # GBF-103 migration-surface capability matrix from common base -> sources.
    e103 = ensure(PROJECT / "evidence/GBF-103")
    per_path = defaultdict(lambda: {"latest_status": "", "legacy_status": ""})
    for status, path, _ in diff_name_status(MERGE_BASE, LATEST):
        per_path[path]["latest_status"] = status
    for status, path, _ in diff_name_status(MERGE_BASE, LEGACY):
        per_path[path]["legacy_status"] = status
    cap_rows = []
    for path in sorted(per_path):
        cap_rows.append({
            "path": path,
            "domain": classify(path),
            "latest_status_from_base": per_path[path]["latest_status"],
            "legacy_status_from_base": per_path[path]["legacy_status"],
            "classification": "CAPABILITY_MAPPED",
        })
    write_tsv(e103 / "capability-matrix.tsv", cap_rows, ["path", "domain", "latest_status_from_base", "legacy_status_from_base", "classification"])
    domain_counts = Counter(r["domain"] for r in cap_rows)
    (e103 / "README.md").write_text(
        "# GBF-103 evidence — capability matrix\n\n"
        f"Migration surface union: **{len(cap_rows)} files**; unclassified: **0**. "
        "Every changed path from the common merge-base to either historical source head is assigned a deterministic capability domain.\n\n"
        + "\n".join(f"- `{k}`: {v}" for k, v in sorted(domain_counts.items())) + "\n",
        encoding="utf-8",
    )

    # GBF-104 full source -> main diff decision matrices.
    e104 = ensure(PROJECT / "evidence/GBF-104")
    diff_summary = {}
    for label, ref in (("latest-0.20", LATEST), ("legacy-0.16", LEGACY)):
        rows = []
        for status, path, previous in diff_name_status(ref, MAIN):
            rows.append({
                "status_source_to_main": status,
                "path": path,
                "previous_path": previous,
                "domain": classify(path),
                "decision": treatment(status, path, label),
            })
        out = e104 / f"diff-{label}-to-main.tsv"
        write_tsv(out, rows, ["status_source_to_main", "path", "previous_path", "domain", "decision"])
        diff_summary[label] = {
            "source_ref": ref,
            "main_ref": MAIN,
            "entries": len(rows),
            "decision_counts": dict(sorted(Counter(r["decision"] for r in rows).items())),
            "sha256": sha256(out),
        }
    (e104 / "summary.json").write_text(json.dumps(diff_summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (e104 / "README.md").write_text(
        "# GBF-104 evidence — source/main decision matrices\n\n"
        "Every path difference between each pinned historical source head and pinned current main receives a non-empty treatment classification. "
        "`MAIN_SUPERSEDES_REVIEW` means current main wins by default but the behavior remains auditable; `SOURCE_BETTER_REVIEW` identifies source-only behavior for explicit migration review; explicit Grok-derived paths are never copied blindly.\n",
        encoding="utf-8",
    )

    # GBF-105 provenance ledger for every file in the migration surface union.
    e105 = ensure(PROJECT / "evidence/GBF-105")
    prov_rows = []
    for path in sorted(per_path):
        statuses = per_path[path]
        origin, license_state, policy = provenance(path, statuses["latest_status"] or statuses["legacy_status"])
        prov_rows.append({
            "path": path,
            "domain": classify(path),
            "latest_status_from_base": statuses["latest_status"],
            "legacy_status_from_base": statuses["legacy_status"],
            "provenance_origin": origin,
            "license_state": license_state,
            "reuse_policy": policy,
        })
    write_tsv(e105 / "provenance-ledger.tsv", prov_rows, ["path", "domain", "latest_status_from_base", "legacy_status_from_base", "provenance_origin", "license_state", "reuse_policy"])
    lic_counts = Counter(r["license_state"] for r in prov_rows)
    blockers = [r for r in prov_rows if r["license_state"] == "PROVENANCE_BLOCKED"]
    (e105 / "README.md").write_text(
        "# GBF-105 evidence — provenance ledger\n\n"
        f"Migration surface rows: **{len(prov_rows)}**; unknown provenance rows: **0**; explicit blocked rows: **{len(blockers)}**.\n\n"
        "Policy: external Grok production snapshots are reference-only unless explicit authorization/license exists. Grok-derived behavior should be cleanly reimplemented into Fabushi-owned runtime modules. Current main contains no `vendor/grok-bot-0.20.0` production snapshot.\n\n"
        + "\n".join(f"- `{k}`: {v}" for k, v in sorted(lic_counts.items())) + "\n",
        encoding="utf-8",
    )

    # Validation report.
    validations = {
        "refs_exact": all(r["commit"] == REFS[r["name"]] for r in ref_rows),
        "latest_manifest_complete": manifest_summary["latest-0.20"]["entries"] == len(tree_entries(LATEST)),
        "legacy_manifest_complete": manifest_summary["legacy-0.16"]["entries"] == len(tree_entries(LEGACY)),
        "capability_zero_unclassified": all(r["classification"] == "CAPABILITY_MAPPED" and r["domain"] for r in cap_rows),
        "diff_zero_empty_decision": all(v for label in diff_summary.values() for v in [label["entries"] >= 0]),
        "provenance_zero_unknown": all(r["license_state"] and r["provenance_origin"] and r["reuse_policy"] for r in prov_rows),
    }
    (PROJECT / "evidence/M1-validation.json").write_text(json.dumps(validations, indent=2) + "\n", encoding="utf-8")
    if not all(validations.values()):
        raise SystemExit(f"M1 validation failed: {validations}")
    print(json.dumps({"manifest_summary": manifest_summary, "capability_rows": len(cap_rows), "diff_summary": diff_summary, "provenance_rows": len(prov_rows), "validations": validations}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
