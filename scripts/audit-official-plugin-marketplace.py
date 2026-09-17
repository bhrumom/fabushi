#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from marketplace_security import audit_official_plugins, fail_if_rejected


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit all official Fabushi marketplace plugins")
    parser.add_argument("--report", type=Path, required=True, help="machine-readable audit report path")
    parser.add_argument("--source-sha", default=os.environ.get("GITHUB_SHA", "unknown"))
    parser.add_argument("--no-fail", action="store_true", help="write the report without exiting non-zero on rejection")
    args = parser.parse_args()

    report = audit_official_plugins(source_sha=args.source_sha)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        f"marketplace security review: {report['decision']} "
        f"({report['summary']['approved']}/{report['summary']['pluginCount']} plugins approved)"
    )
    if not args.no_fail:
        fail_if_rejected(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
