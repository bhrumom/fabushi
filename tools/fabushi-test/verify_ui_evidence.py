#!/usr/bin/env python3
"""Fail closed unless each registered UI journey retains its own evidence."""
from __future__ import annotations

import base64
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import zipfile

CHECKPOINTS = {
    'real renderer hydrates and exposes masked semantic state without an App package': ['01-hydrated-real-renderer'],
    'semantic actions reach the actual profile UI and stale actions fail closed': ['01-before-profile', '02-profile-open'],
    'missing semantic targets and unmet conditions never report success': ['01-negative-semantics'],
}


def specs(suites):
    for suite in suites:
        yield from suite.get('specs', [])
        yield from specs(suite.get('suites', []))


def attachment_bytes(attachment: dict, root: Path) -> bytes:
    if attachment.get('path'):
        path = Path(attachment['path'])
        if not path.is_absolute():
            raise ValueError('attachment must use an absolute path from this CI run')
        path = path.resolve()
        if not path.is_relative_to(root.resolve()) or not path.is_file():
            raise ValueError('attachment missing or outside evidence root')
        if path.stat().st_size > 64 * 1024 * 1024:
            raise ValueError('attachment exceeds evidence verification limit')
        value = path.read_bytes()
    else:
        value = base64.b64decode(attachment.get('body', ''), validate=True)
    if not value:
        raise ValueError('empty evidence attachment')
    return value


def require_attachment(by_name: dict[str, dict], name: str, content_type: str) -> dict:
    attachment = by_name.get(name)
    if attachment is None:
        raise ValueError(f'missing required attachment: {name}')
    if attachment.get('contentType') != content_type:
        raise ValueError(f'invalid content type for {name}: expected {content_type}')
    return attachment


def verify(report: dict, root: Path, required: dict | None = None) -> dict:
    required = CHECKPOINTS if required is None else required
    stats = report['stats']
    if report.get('errors') or any(stats.get(k) != 0 for k in ('unexpected', 'skipped', 'flaky')):
        raise ValueError('report contains errors, skipped tests or retries')
    items = list(specs(report['suites']))
    if not required or len(items) != len(required) or stats.get('expected') != len(required):
        raise ValueError('registered journey count mismatch')
    seen = set()
    result = []
    for spec in items:
        title = spec['title']
        if title not in required or title in seen or spec.get('ok') is not True:
            raise ValueError('unknown, duplicate or unsuccessful journey')
        seen.add(title)
        tests = spec['tests']
        if len(tests) != 1 or tests[0].get('expectedStatus') != 'passed' or tests[0].get('status') != 'expected':
            raise ValueError('unexpected test outcome')
        attempts = tests[0]['results']
        if len(attempts) != 1 or attempts[0].get('status') != 'passed' or attempts[0].get('retry') != 0:
            raise ValueError('not a first-attempt pass')
        attachments = attempts[0]['attachments']
        by_name: dict[str, dict] = {}
        for attachment in attachments:
            name = attachment.get('name')
            if not isinstance(name, str) or not name or name in by_name:
                raise ValueError('invalid or duplicate attachment name')
            by_name[name] = attachment
        for checkpoint in required[title]:
            require_attachment(by_name, checkpoint + '.png', 'image/png')
            require_attachment(by_name, checkpoint + '.json', 'application/json')
        require_attachment(by_name, 'video', 'video/webm')
        require_attachment(by_name, 'trace', 'application/zip')
        digests = []
        for attachment in attachments:
            data = attachment_bytes(attachment, root)
            kind = attachment['contentType']
            name = attachment['name']
            if kind == 'image/png' and not data.startswith(b'\x89PNG\r\n\x1a\n'):
                raise ValueError('invalid PNG evidence')
            if kind == 'application/json':
                json.loads(data)
            if name == 'trace':
                with zipfile.ZipFile(io.BytesIO(data)) as archive:
                    if not any(n.endswith('.trace') for n in archive.namelist()):
                        raise ValueError('trace archive has no action trace')
            if name == 'video' and not data.startswith(b'\x1a\x45\xdf\xa3'):
                raise ValueError('invalid WebM evidence')
            digests.append({'name': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
        result.append({'title': title, 'duration_ms': attempts[0]['duration'], 'attachments': digests})
    return {'schema': 'fabushi.ui-evidence.v1', 'status': 'passed', 'journeys': result,
            'scope': 'registered real-renderer presentation journeys only', 'full_product_acceptance': False}


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    evidence = root / '.fast-ui-evidence'
    try:
        sha = os.environ.get('EXPECTED_SHA', '')
        if os.environ.get('GITHUB_ACTIONS') != 'true' or not re.fullmatch(r'[0-9a-f]{40}', sha):
            raise ValueError('exact-source GitHub Actions context required')
        if subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip() != sha:
            raise ValueError('source mismatch')
        report = json.loads((evidence / 'results.json').read_text())
        result = verify(report, evidence)
        result.update(source_sha=sha, run_id=os.environ.get('GITHUB_RUN_ID'))
        (evidence / 'evidence-manifest.json').write_text(json.dumps(result, indent=2) + '\n')
        print('FABUSHI_UI_EVIDENCE_VERIFIED', len(result['journeys']))
        return 0
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile, subprocess.SubprocessError) as error:
        print('UI evidence incomplete:', type(error).__name__, str(error))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
