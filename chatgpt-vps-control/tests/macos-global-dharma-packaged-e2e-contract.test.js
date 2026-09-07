import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const workflowPath = new URL('../../.github/workflows/macos-global-dharma-packaged-e2e.yml', import.meta.url);
const journeyPath = new URL('../../desktop/e2e/miniapp-bot-parity.spec.ts', import.meta.url);

async function sources() {
  return Promise.all([readFile(workflowPath, 'utf8'), readFile(journeyPath, 'utf8')]);
}

test('macOS Global Dharma acceptance is CI-native and never requires the external device plugin', async () => {
  const [workflow] = await sources();
  assert.match(workflow, /name:\s*macOS Global Dharma packaged E2E/u);
  assert.match(workflow, /release:\s*\n\s*types:\s*\[published\]/u);
  assert.match(workflow, /pull_request:/u);
  assert.match(workflow, /runs-on:\s*macos-15/u);
  assert.match(workflow, /npx playwright test e2e\/miniapp-bot-parity\.spec\.ts/u);

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
  const [workflow, journey] = await sources();
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

test('packaged user journey covers search, install, Bot/WebMCP parity, CNY 1080 purchase/restore and local prayer-wheel authorization', async () => {
  const [, journey] = await sources();
  const required = [
    "fill('全球法布施')",
    "global-search-app-global-dharma",
    "getByRole('button', { name: '安装' })",
    "getByTestId('miniapp-bot-open')",
    "source: 'bot'",
    "tool: 'status'",
    "iframe[title=\"global-dharma\"]",
    "['status', 'start', 'stop', 'send']",
    "productId: 'prod.global-dharma.local-prayer-wheel.lifetime'",
    "productKind: 'digital_durable'",
    "currency: 'CNY'",
    'amount: 108000',
    "getByTestId('fabushi-miniapp-purchase-lifetime')",
    "toContainText('¥1080')",
    "getByTestId('fabushi-miniapp-restore-purchases')",
    "fill(prayerText)",
    "surface: 'local-prayer-wheel'",
    'entitlementAllowed: true',
    "getByTestId('settings-logout')",
  ];
  for (const needle of required) assert.ok(journey.includes(needle), `missing packaged journey assertion: ${needle}`);
});

test('macOS Global Dharma evidence requires named screenshots, segmented journey videos, trace and report', async () => {
  const [workflow, journey] = await sources();
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
