import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const workflowPath = new URL('../../.github/workflows/macos-global-dharma-packaged-e2e.yml', import.meta.url);
const publisherWorkflowPath = new URL('../../.github/workflows/global-dharma-exact-main-evidence-publish.yml', import.meta.url);
const entryJourneyPath = new URL('../../desktop/e2e/miniapp-search-entry.spec.ts', import.meta.url);
const journeyPath = new URL('../../desktop/e2e/miniapp-bot-parity.spec.ts', import.meta.url);
const composerBridgePath = new URL('../../desktop/src/miniapp-composer-open-bridge.ts', import.meta.url);
const serviceWorkflowPath = new URL('../../.github/workflows/global-dharma-web-service-contract.yml', import.meta.url);

async function sources() {
  return Promise.all([
    readFile(workflowPath, 'utf8'),
    readFile(entryJourneyPath, 'utf8'),
    readFile(journeyPath, 'utf8'),
    readFile(composerBridgePath, 'utf8'),
    readFile(publisherWorkflowPath, 'utf8'),
  ]);
}

test('macOS Global Dharma acceptance is CI-native and never requires the external device plugin', async () => {
  const [workflow] = await sources();
  assert.match(workflow, /name:\s*macOS Global Dharma packaged E2E/u);
  assert.match(workflow, /release:\s*\n\s*types:\s*\[published\]/u);
  assert.match(workflow, /pull_request:/u);
  assert.match(workflow, /runs-on:\s*macos-15/u);
  assert.match(workflow, /npx playwright test e2e\/miniapp-search-entry\.spec\.ts e2e\/miniapp-bot-parity\.spec\.ts/u);

  for (const forbidden of [
    '@fabushi test',
    'ci_session_',
    'fabushi.app.status',
    'fabushi.app.snapshot',
    'fabushi.app.find',
    'fabushi.app.action',
    'fabushi.app.wait',
    'fabushi.app.assert',
    'Hold for',
  ]) {
    assert.equal(workflow.includes(forbidden), false, `${forbidden} must not be a prerequisite of the CI-native journey`);
  }
});

test('macOS Global Dharma acceptance reuses an exact published package instead of rebuilding locally', async () => {
  const [workflow] = await sources();
  assert.match(workflow, /actions\/setup-node@v6/u);
  assert.match(workflow, /cache:\s*npm/u);
  assert.match(workflow, /gh release download/u);
  assert.match(workflow, /target_commitish/u);
  assert.match(workflow, /resolved_target/u);
  assert.match(workflow, /test "\$resolved_target" = "\$source_sha"/u);
  assert.ok(workflow.includes('^fabushi-[0-9]+\\\\.[0-9]+\\\\.[0-9]+-macos-arm64\\\\.zip$'));
  assert.match(workflow, /codesign --verify --deep --strict/u);
  assert.match(workflow, /spctl --assess --type execute/u);

  for (const forbidden of ['electron-builder', 'xcodebuild', 'cargo build', 'npm run build:host', 'npm run build:renderer']) {
    assert.equal(workflow.includes(forbidden), false, `${forbidden} would turn this focused reuse gate into a rebuild`);
  }
});

test('macOS Global Dharma journey uses protected Fabushi account projection and exact-SHA service entitlement evidence', async () => {
  const [workflow, , journey] = await sources();
  assert.match(workflow, /login-ci-test-account\.mjs/u);
  assert.match(workflow, /export-ci-app-account-session\.mjs/u);
  assert.match(workflow, /FABUSHI_CI_ACCOUNT_SESSION_FILE/u);
  assert.match(workflow, /jq -e '\.refreshToken \| not'/u);
  assert.match(workflow, /global-dharma-web-service-contract\.yml/u);
  assert.match(workflow, /head_sha == \$sha/u);
  assert.match(workflow, /conclusion == "success"/u);

  assert.match(journey, /getMiniAppSessionProjection/u);
  assert.match(journey, /loggedIn:\s*true/u);
  assert.match(journey, /tokenExposed:\s*false/u);
  assert.match(journey, /accessToken\|refreshToken\|bearer/i);
});

test('exact-SHA service entitlement evidence self-starts on canonical main release changes', async () => {
  const serviceWorkflow = await readFile(serviceWorkflowPath, 'utf8');
  assert.match(serviceWorkflow, /push:\s*\n\s*branches:\s*\[main\]/u);
  assert.ok(serviceWorkflow.includes("- 'app-version.json'"));
  assert.ok(serviceWorkflow.includes("- '.github/workflows/macos-global-dharma-packaged-e2e.yml'"));
  assert.match(serviceWorkflow, /CNY 1080 order\/webhook\/refund\/restore contract/u);
});

test('exact-main evidence publication is desktop-only, provenance-bound, direct-downloadable and fail-closed', async () => {
  const [, , , , publisher] = await sources();
  for (const needle of [
    'workflow_run:',
    'Electron desktop quality gate',
    "github.event.workflow_run.event == 'push'",
    "github.event.workflow_run.head_branch == 'main'",
    "github.event.workflow_run.conclusion == 'success'",
    'SOURCE_SHA: ${{ github.event.workflow_run.head_sha }}',
    'ELECTRON_RUN_ID: ${{ github.event.workflow_run.id }}',
    'fabushi-electron-mac-e2e-diagnostics',
    'actions/download-artifact@v8.0.1',
    'digest-mismatch: error',
    "require_one 'global-dharma-user-journey.webm'",
    "require_one 'global-dharma-user-journey-restart-logout.webm'",
    "require_one 'miniapp-search-entry-user-journey.webm'",
    "require_one '03-global-dharma-bot-composer-open-app-adjacent.png'",
    'sha256sum *.webm *.png *.zip',
    'ORIGINAL_ARTIFACT_DIGEST',
    'ORIGINAL_ARTIFACT_UI_URL',
    'gh release create "$TAG"',
    '--target "$SOURCE_SHA"',
    '--prerelease',
    'productionPspKycVerified: false',
  ]) {
    assert.ok(publisher.includes(needle), `missing exact-main evidence publication invariant: ${needle}`);
  }
  for (const forbidden of [
    'native-mobile.yml',
    'fabushi-native-',
    'Native mobile result',
    'needs.wait-native',
    'native_run_id',
  ]) {
    assert.equal(publisher.includes(forbidden), false, `${forbidden} must not gate desktop Global Dharma evidence publication`);
  }
});

test('packaged user journey covers exact 小程序 discovery/install plus Bot/WebMCP parity, CNY 1080 purchase/restore and local prayer-wheel authorization', async () => {
  const [, entryJourney, journey, composerBridge] = await sources();
  for (const needle of [
    "fill('小程序')",
    'global-search-app-global-dharma',
    "name: '安装'",
    "name: '打开'",
  ]) {
    assert.ok(entryJourney.includes(needle), `missing exact Mini App entry assertion: ${needle}`);
  }

  for (const needle of [
    "getByTestId('miniapp-bot-open')",
    'sameForm',
    'immediatelyAfterInput',
    'horizontalGap',
    'overlapRatio',
    'toBeLessThanOrEqual(24)',
    'toBeGreaterThanOrEqual(0.6)',
    '03-global-dharma-bot-composer-open-app-adjacent.png',
  ]) {
    assert.ok(entryJourney.includes(needle), `missing composer placement assertion: ${needle}`);
  }

  for (const needle of [
    "const SOURCE_TEST_ID = 'miniapp-bot-open-source'",
    "const OPEN_TEST_ID = 'miniapp-bot-open'",
    "bridge.className = 'fabushi-miniapp-composer-open'",
    'source.hidden = true',
    "input.insertAdjacentElement('afterend', bridge)",
  ]) {
    assert.ok(composerBridge.includes(needle), `missing composer bridge contract: ${needle}`);
  }

  const required = [
    "fill('全球法布施')",
    'global-search-app-global-dharma',
    "getByRole('button', { name: '安装' })",
    "getByTestId('miniapp-bot-open')",
    "source: 'bot'",
    "tool: 'status'",
    'iframe[title="global-dharma"]',
    "['status', 'start', 'stop', 'send']",
    "productId: 'prod.global-dharma.local-prayer-wheel.lifetime'",
    "productKind: 'digital_durable'",
    "currency: 'CNY'",
    'amount: 108000',
    "getByTestId('fabushi-miniapp-purchase-lifetime')",
    "toContainText('¥1080')",
    "getByTestId('fabushi-miniapp-restore-purchases')",
    'fill(prayerText)',
    "surface: 'local-prayer-wheel'",
    'entitlementAllowed: true',
    "getByTestId('settings-logout')",
  ];
  for (const needle of required) assert.ok(journey.includes(needle), `missing packaged journey assertion: ${needle}`);
});

test('macOS Global Dharma evidence requires entry and parity screenshots, segmented journey videos, trace and report', async () => {
  const [workflow, entryJourney, journey] = await sources();
  for (const name of [
    '01-search-miniapp-finds-global-dharma.png',
    '02-global-dharma-installed-from-miniapp-search.png',
  ]) {
    assert.ok(entryJourney.includes(name));
    assert.ok(workflow.includes(name));
  }
  assert.ok(entryJourney.includes('03-global-dharma-bot-composer-open-app-adjacent.png'));
  assert.match(workflow, /desktop\/test-results\/\*\*\/\*\.webm/u);
  assert.match(workflow, /desktop\/test-results/u);
  assert.match(entryJourney, /miniapp-search-entry-user-journey\.webm/u);
  assert.match(workflow, /miniapp-search-entry-user-journey\.webm/u);

  for (let index = 1; index <= 12; index += 1) {
    const prefix = String(index).padStart(2, '0');
    assert.match(journey, new RegExp(`'${prefix}-[^']+\\.png'`, 'u'));
    assert.match(workflow, new RegExp(`${prefix}-.*\\.png`, 'u'));
  }
  assert.match(journey, /global-dharma-user-journey\.webm/u);
  assert.match(journey, /global-dharma-user-journey-restart-logout\.webm/u);
  assert.match(workflow, /global-dharma-user-journey\.webm/u);
  assert.match(workflow, /global-dharma-user-journey-restart-logout\.webm/u);
  assert.match(workflow, /trace\.zip/u);
  assert.match(workflow, /playwright-report\/index\.html/u);
  assert.match(workflow, /macos-session\.mov/u);
  assert.match(workflow, /actions\/upload-artifact@v7/u);
});
