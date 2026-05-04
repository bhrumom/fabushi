#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re
import sys

workflow = Path('.github/workflows/publish-cd-release.yml').read_text(encoding='utf-8')
match = re.search(
    r"- name: Checkout source for version metadata\n(?P<body>.*?)\n\s*- name: Prepare release assets",
    workflow,
    re.DOTALL,
)

if not match:
    sys.stderr.write('Could not find the version metadata checkout step in publish-cd-release.yml\n')
    raise SystemExit(1)

body = match.group('body')
missing = []
for required in ('clean: false', 'path: version-metadata'):
    if required not in body:
        missing.append(required)

if missing:
    sys.stderr.write(
        'publish-cd-release.yml is missing required checkout guardrails: ' + ', '.join(missing) + '\n'
    )
    raise SystemExit(1)

print('publish-cd-release checkout guardrails are in place')
PY
