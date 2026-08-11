#!/usr/bin/env python3
"""Find the newest non-expired GitHub Actions artifact by exact name.

This is intentionally dependency-free so the iOS canary can reuse build
artifacts before Flutter, CocoaPods, Node setup, or any other toolchain work.
"""

from __future__ import annotations

import argparse
import json
import os
import urllib.parse
import urllib.request
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True)
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--token", default=os.environ.get("GITHUB_TOKEN", ""))
    parser.add_argument("--github-output", default=os.environ.get("GITHUB_OUTPUT", ""))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.repository or "/" not in args.repository:
        raise SystemExit("GITHUB_REPOSITORY/--repository must be owner/repo")
    if not args.token:
        raise SystemExit("GITHUB_TOKEN/--token is required")
    if not args.github_output:
        raise SystemExit("GITHUB_OUTPUT/--github-output is required")

    encoded_name = urllib.parse.quote(args.name, safe="")
    url = (
        f"https://api.github.com/repos/{args.repository}/actions/artifacts"
        f"?name={encoded_name}&per_page=100"
    )
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {args.token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "fabushi-ios-e2e-artifact-cache",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.loads(response.read().decode("utf-8"))

    candidates = [
        artifact
        for artifact in payload.get("artifacts", [])
        if artifact.get("name") == args.name and not artifact.get("expired", False)
    ]
    candidates.sort(key=lambda artifact: str(artifact.get("created_at", "")), reverse=True)

    output_path = Path(args.github_output)
    with output_path.open("a", encoding="utf-8") as handle:
        if not candidates:
            handle.write("hit=false\n")
            handle.write(f"name={args.name}\n")
            print(json.dumps({"hit": False, "name": args.name}))
            return 0

        artifact = candidates[0]
        workflow_run = artifact.get("workflow_run") or {}
        run_id = workflow_run.get("id")
        if not run_id:
            raise SystemExit(f"Artifact {artifact.get('id')} is missing workflow_run.id")
        handle.write("hit=true\n")
        handle.write(f"name={args.name}\n")
        handle.write(f"run_id={run_id}\n")
        handle.write(f"artifact_id={artifact.get('id')}\n")
        print(
            json.dumps(
                {
                    "hit": True,
                    "name": args.name,
                    "runId": run_id,
                    "artifactId": artifact.get("id"),
                    "createdAt": artifact.get("created_at"),
                }
            )
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
