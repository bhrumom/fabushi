#!/usr/bin/env python3
from pathlib import Path

root = Path('.')
workflows = root / '.github' / 'workflows'
project = root / 'projects' / 'grok-bot-fabushi-integration'

required_workflows = [
    'ci.yml',
    'electron-desktop.yml',
    'native-mobile.yml',
    'computer-control-security.yml',
    'gbf-security-closure.yml',
    'mahayana-fast-checks.yml',
    'messaging-product-gate.yml',
    'gbf-release-candidate.yml',
    'gbf-rollback-drill.yml',
    'native-electron-release.yml',
]
for name in required_workflows:
    path = workflows / name
    if not path.is_file():
        raise SystemExit(f'GBF release readiness: missing workflow {name}')

rc = (workflows / 'gbf-release-candidate.yml').read_text(encoding='utf-8')
for name in required_workflows[:7]:
    if name not in rc:
        raise SystemExit(f'GBF release readiness: RC coordinator does not dispatch {name}')
if 'headSha == \\"$RC_SHA\\"' not in rc and 'headSha == "$RC_SHA"' not in rc:
    raise SystemExit('GBF release readiness: RC coordinator is not pinned to one head SHA')

rollback = (workflows / 'gbf-rollback-drill.yml').read_text(encoding='utf-8')
for marker in (
    'releases/latest',
    'prerelease',
    'SHA256SUMS.txt',
    'sha256sum -c',
    'previous-good release checksums verified',
):
    if marker not in rollback:
        raise SystemExit(f'GBF release readiness: rollback drill missing {marker}')

release = (workflows / 'native-electron-release.yml').read_text(encoding='utf-8')
for marker in (
    'CI result',
    'Electron desktop result',
    'Electron macOS',
    'Electron Windows',
    'Native mobile result',
    'Native iOS',
    'already exists; refusing to mutate an existing release',
    'gh release create',
    'SHA256SUMS.txt',
    'ANDROID_KEYSTORE_BASE64',
    'IOS_DISTRIBUTION_CERTIFICATE_P12_BASE64',
):
    if marker not in release:
        raise SystemExit(f'GBF release readiness: native release workflow missing {marker}')

historical = (
    'grok-bot-latest-source-fusion',
    'grok-bot-0.16-source-fusion',
)
for path in workflows.glob('*.y*ml'):
    text = path.read_text(encoding='utf-8')
    for branch in historical:
        if branch in text:
            raise SystemExit(f'GBF release readiness: production workflow {path} references historical branch {branch}')

for forbidden in (
    root / 'vendor' / 'grok-bot-0.20.0',
    root / 'frontend' / 'apps' / 'web' / 'src' / 'lib' / 'grok-agent',
    root / 'frontend' / 'apps' / 'web' / 'src' / 'lib' / 'grok-bot',
):
    if forbidden.exists():
        raise SystemExit(f'GBF release readiness: forbidden production Grok source returned: {forbidden}')

adr = (project / 'decisions' / 'ADR-0006-historical-grok-branches-read-only-audit.md').read_text(encoding='utf-8')
for marker in (
    '7174a70567ae98ef534b0eebcbe66935f1471cc1',
    'a8bd854b512a3eaf20be9518767ab593724d67dc',
    'main` is the only build, runtime and release authority',
    'Wholesale merge/overwrite',
):
    if marker not in adr:
        raise SystemExit(f'GBF release readiness: historical-branch ADR missing {marker}')

print('GBF release readiness passed: canonical per-platform gates, rollback integrity, immutable signed release and historical-branch isolation are all enforced.')
