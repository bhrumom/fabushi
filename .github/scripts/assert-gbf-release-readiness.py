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
    'release-desktop-platform.yml',
    'release-macos.yml',
    'release-windows.yml',
    'release-linux.yml',
    'native-android-release.yml',
    'release-ios.yml',
]
for name in required_workflows:
    if not (workflows / name).is_file():
        raise SystemExit(f'GBF release readiness: missing workflow {name}')

rc = (workflows / 'gbf-release-candidate.yml').read_text(encoding='utf-8')
if 'workflow_dispatch:' not in rc or 'pull_request:' in rc or '\n  push:' in rc:
    raise SystemExit('GBF release readiness: RC fan-out must be explicit/manual only')

fast = (workflows / 'electron-desktop.yml').read_text(encoding='utf-8')
for forbidden in ('npm run test:e2e', 'npx electron-builder', 'Build and stage CI native Host'):
    if forbidden in fast:
        raise SystemExit(f'GBF release readiness: automatic Electron fast gate contains heavy step {forbidden}')
for marker in ('Electron desktop result', 'npx tsc --noEmit', 'npx vite build'):
    if marker not in fast:
        raise SystemExit(f'GBF release readiness: Electron fast gate missing {marker}')

reusable = (workflows / 'release-desktop-platform.yml').read_text(encoding='utf-8')
for marker in (
    "inputs.release_kind == 'formal'",
    'npx electron-builder --${{ inputs.platform }} --publish never',
    'npm run test:e2e',
    '--prerelease --latest=false',
):
    if marker not in reusable:
        raise SystemExit(f'GBF release readiness: reusable desktop release missing {marker}')

for marker in (
    'Install Developer ID identity for macOS release',
    "if: inputs.platform == 'mac'",
    "CSC_IDENTITY_AUTO_DISCOVERY: ${{ inputs.platform == 'mac' && 'true' || 'false' }}",
    "FABUSHI_MACOS_SIGNED: ${{ inputs.platform == 'mac' && '1' || '0' }}",
    "FABUSHI_MACOS_NOTARIZE: ${{ inputs.platform == 'mac' && inputs.release_kind == 'formal' && '1' || '0' }}",
):
    if marker not in reusable:
        raise SystemExit(f'GBF release readiness: macOS test/formal signing contract missing {marker}')

for marker in (
    'export CHATGPT_COMPUTER_CODESIGN_IDENTITY=',
    'export CHATGPT_COMPUTER_TEAM_ID=',
    'Verify packaged Computer Use runtime and signing boundary',
    '--expected-mac-team',
):
    if marker not in reusable:
        raise SystemExit(f'GBF release readiness: packaged Computer Use signing verification missing {marker}')
identity_step = reusable.index('Install Developer ID identity for macOS release')
staging_step = reusable.index('node chatgpt-vps-control/bin/prepare-fabushi-bundle.js')
package_step = reusable.index('npx electron-builder --${{ inputs.platform }} --publish never')
verify_step = reusable.index('node .github/scripts/verify-packaged-computer-control.mjs', package_step)
if not identity_step < staging_step < package_step < verify_step:
    raise SystemExit('GBF release readiness: macOS identity -> Computer Use staging -> package -> package verification order is invalid')

desktop_package = (root / 'desktop' / 'package.json').read_text(encoding='utf-8')
if '"forceCodeSigning": true' not in desktop_package:
    raise SystemExit('GBF release readiness: macOS package must fail closed instead of emitting an unsigned test artifact')

mac_after_sign = (root / 'desktop' / 'scripts' / 'notarize-after-sign.cjs').read_text(encoding='utf-8')
for marker in (
    "const signedRelease = process.env.FABUSHI_MACOS_SIGNED === '1';",
    "const notarizeRelease = process.env.FABUSHI_MACOS_NOTARIZE === '1';",
    'restoreCanonicalNestedSignatures(context, appPath);',
    'if (!notarizeRelease) return;',
    "identifier: 'com.ombhrum.fabushi.mahayana-app-host'",
):
    if marker not in mac_after_sign:
        raise SystemExit(f'GBF release readiness: signed fast Mac package hook missing {marker}')

for name, target in (
    ('release-macos.yml', 'platform: mac'),
    ('release-windows.yml', 'platform: win'),
    ('release-linux.yml', 'platform: linux'),
):
    text = (workflows / name).read_text(encoding='utf-8')
    for marker in ('workflow_dispatch:', 'release_kind:', 'options: [test, formal]', target):
        if marker not in text:
            raise SystemExit(f'GBF release readiness: {name} missing {marker}')

for name in ('native-android-release.yml', 'release-ios.yml'):
    text = (workflows / name).read_text(encoding='utf-8')
    for marker in ('workflow_dispatch:', 'release_kind:', 'options: [test, formal]', 'intentionally blocked until'):
        if marker not in text:
            raise SystemExit(f'GBF release readiness: {name} missing {marker}')

legacy = (workflows / 'native-electron-release.yml').read_text(encoding='utf-8')
if 'Legacy combined release (disabled)' not in legacy:
    raise SystemExit('GBF release readiness: old combined five-platform release is not disabled')

rollback = (workflows / 'gbf-rollback-drill.yml').read_text(encoding='utf-8')
for marker in ('releases?per_page=100', 'prerelease', 'SHA256SUMS.txt', 'sha256sum -c', 'previous-good release checksums verified'):
    if marker not in rollback:
        raise SystemExit(f'GBF release readiness: rollback drill missing {marker}')

historical = ('grok-bot-latest-source-fusion', 'grok-bot-0.16-source-fusion')
production_release_workflows = [workflows / name for name in required_workflows]
for path in production_release_workflows:
    text = path.read_text(encoding='utf-8')
    for branch in historical:
        if branch in text:
            raise SystemExit(f'GBF release readiness: production release workflow {path} references historical branch {branch}')

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

print('GBF release readiness passed: fast automatic gates, manual platform-isolated test/formal releases, rollback integrity, and historical-branch isolation are enforced.')
