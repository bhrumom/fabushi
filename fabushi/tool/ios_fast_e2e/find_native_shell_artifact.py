#!/usr/bin/env python3
"""Find the newest compatible prebuilt iOS Runner shell artifact.

A shell is reusable across Dart/UI/assets changes, but not across iOS project,
pubspec, or Mahayana native runtime changes. The decision is grounded in the
tracked file diff between the producing PR commit and the current PR commit.
"""

from __future__ import annotations

import argparse
import json
import os
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

NATIVE_PREFIXES = (
    "fabushi/ios/",
    "third_party/mahayana/",
)
NATIVE_EXACT = {
    "fabushi/pubspec.yaml",
    "fabushi/pubspec.lock",
}
EXPECTED_WORKFLOW = "iOS External MiniApp E2E"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prefix", required=True)
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--token", default=os.environ.get("GITHUB_TOKEN", ""))
    parser.add_argument("--github-output", default=os.environ.get("GITHUB_OUTPUT", ""))
    parser.add_argument("--max-pages", type=int, default=3)
    return parser.parse_args()


def api_json(url: str, token: str) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "fabushi-ios-fast-e2e",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.loads(response.read().decode("utf-8"))
    if not isinstance(payload, dict):
        raise RuntimeError(f"Expected object response from {url}")
    return payload


def current_pr_context() -> tuple[str, str | None]:
    event_path = Path(os.environ.get("GITHUB_EVENT_PATH", ""))
    if event_path.is_file():
        try:
            event = json.loads(event_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            event = {}
        pr = event.get("pull_request") if isinstance(event, dict) else None
        if isinstance(pr, dict):
            head = pr.get("head")
            base = pr.get("base")
            head_sha = head.get("sha") if isinstance(head, dict) else None
            base_sha = base.get("sha") if isinstance(base, dict) else None
            if isinstance(head_sha, str) and head_sha:
                return head_sha, base_sha if isinstance(base_sha, str) else None
    sha = os.environ.get("GITHUB_SHA", "")
    if not sha:
        raise RuntimeError("Could not resolve current GitHub SHA")
    return sha, None


def run_pr_base(repository: str, token: str, run_id: int) -> tuple[str | None, str | None]:
    payload = api_json(
        f"https://api.github.com/repos/{repository}/actions/runs/{run_id}", token
    )
    workflow_name = payload.get("name")
    prs = payload.get("pull_requests")
    if not isinstance(prs, list) or not prs:
        return (str(workflow_name) if workflow_name is not None else None, None)
    pr = prs[0]
    if not isinstance(pr, dict):
        return (str(workflow_name) if workflow_name is not None else None, None)
    base = pr.get("base")
    base_sha = base.get("sha") if isinstance(base, dict) else None
    return (
        str(workflow_name) if workflow_name is not None else None,
        base_sha if isinstance(base_sha, str) else None,
    )


def native_relevant(path: str) -> bool:
    return path in NATIVE_EXACT or path.startswith(NATIVE_PREFIXES)


def compatible(
    *,
    repository: str,
    token: str,
    candidate_head: str,
    candidate_base: str | None,
    current_head: str,
    current_base: str | None,
) -> tuple[bool, str]:
    if current_base is not None:
        if candidate_base is None:
            return False, "candidate has no PR base SHA"
        if candidate_base != current_base:
            return False, "PR base changed"
    if candidate_head == current_head:
        return True, "same PR head"

    url = (
        f"https://api.github.com/repos/{repository}/compare/"
        f"{urllib.parse.quote(candidate_head, safe='')}..."
        f"{urllib.parse.quote(current_head, safe='')}"
    )
    payload = api_json(url, token)
    files = payload.get("files")
    if not isinstance(files, list):
        return False, "compare response has no files"
    if len(files) >= 300:
        return False, "compare reached GitHub file-list safety ceiling"
    changed = [
        str(row.get("filename"))
        for row in files
        if isinstance(row, dict)
        and isinstance(row.get("filename"), str)
        and native_relevant(str(row["filename"]))
    ]
    if changed:
        return False, "native inputs changed: " + ", ".join(changed[:5])
    return True, "only Dart/UI/test-harness inputs changed"


def write_outputs(path: Path, values: dict[str, str]) -> None:
    with path.open("a", encoding="utf-8") as handle:
        for key, value in values.items():
            handle.write(f"{key}={value}\n")


def main() -> int:
    args = parse_args()
    if not args.repository or "/" not in args.repository:
        raise SystemExit("--repository/GITHUB_REPOSITORY must be owner/repo")
    if not args.token:
        raise SystemExit("--token/GITHUB_TOKEN is required")
    if not args.github_output:
        raise SystemExit("--github-output/GITHUB_OUTPUT is required")

    current_head, current_base = current_pr_context()
    candidates: list[dict[str, Any]] = []
    for page in range(1, max(args.max_pages, 1) + 1):
        payload = api_json(
            f"https://api.github.com/repos/{args.repository}/actions/artifacts"
            f"?per_page=100&page={page}",
            args.token,
        )
        rows = payload.get("artifacts")
        if not isinstance(rows, list) or not rows:
            break
        candidates.extend(
            row
            for row in rows
            if isinstance(row, dict)
            and isinstance(row.get("name"), str)
            and str(row["name"]).startswith(args.prefix)
            and not row.get("expired", False)
        )
        if len(rows) < 100:
            break
    candidates.sort(key=lambda row: str(row.get("created_at", "")), reverse=True)

    rejected: list[dict[str, str]] = []
    for artifact in candidates:
        workflow_run = artifact.get("workflow_run")
        if not isinstance(workflow_run, dict):
            continue
        run_id = workflow_run.get("id")
        candidate_head = workflow_run.get("head_sha")
        if not isinstance(run_id, int) or not isinstance(candidate_head, str):
            continue
        workflow_name, candidate_base = run_pr_base(args.repository, args.token, run_id)
        if workflow_name != EXPECTED_WORKFLOW:
            rejected.append({"name": str(artifact.get("name")), "reason": "wrong workflow"})
            continue
        ok, reason = compatible(
            repository=args.repository,
            token=args.token,
            candidate_head=candidate_head,
            candidate_base=candidate_base,
            current_head=current_head,
            current_base=current_base,
        )
        if not ok:
            rejected.append({"name": str(artifact.get("name")), "reason": reason})
            continue
        result = {
            "hit": "true",
            "name": str(artifact["name"]),
            "run_id": str(run_id),
            "artifact_id": str(artifact.get("id", "")),
            "producer_sha": candidate_head,
        }
        write_outputs(Path(args.github_output), result)
        print(json.dumps({**result, "reason": reason}))
        return 0

    result = {"hit": "false"}
    write_outputs(Path(args.github_output), result)
    print(
        json.dumps(
            {
                **result,
                "prefix": args.prefix,
                "candidateCount": len(candidates),
                "rejected": rejected[:10],
            }
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
