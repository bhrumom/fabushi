import { _electron as electron } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

const [executablePath, expectedVersion, evidencePath] = process.argv.slice(2);
if (!executablePath || !expectedVersion || !evidencePath) {
  throw new Error('Usage: node verify-release-updater-ui.mjs <previous-executable> <expected-version> <evidence-json>');
}

await mkdir(path.dirname(evidencePath), { recursive: true });

const app = await electron.launch({
  executablePath,
  args: [],
  env: {
    ...process.env,
    FABUSHI_FEATURE_HOST_MODE: 'test',
    FABUSHI_APP_DATA: path.join(process.env.RUNNER_TEMP || '/tmp', `fabushi-updater-e2e-${Date.now()}`),
  },
});

let applicationClosed = false;
app.on('close', () => { applicationClosed = true; });
const observedStates = [];
let buttonText = '';
let sawProgressIndicator = false;

async function completeBrowserLogin(page) {
  await page.waitForLoadState('domcontentloaded');
  await page.waitForFunction(() => ['onboarding-gate', 'login-gate', 'messenger-workspace']
    .some((id) => Boolean(document.querySelector(`[data-testid="${id}"]`))), undefined, { timeout: 30_000 });

  while (await page.getByTestId('onboarding-gate').isVisible().catch(() => false)) {
    await page.getByTestId('onboarding-next').click();
  }
  if (await page.getByTestId('login-gate').isVisible().catch(() => false)) {
    await page.getByTestId('browser-login-start').click();
  }
  await page.getByTestId('messenger-workspace').waitFor({ state: 'visible', timeout: 30_000 });
}

try {
  const page = await app.firstWindow();
  await completeBrowserLogin(page);
  const update = page.getByTestId('desktop-update-cloud');
  await update.waitFor({ state: 'visible', timeout: 90_000 });

  buttonText = (await update.textContent())?.trim() || '';
  const initialState = await update.getAttribute('data-state');
  if (initialState) observedStates.push(initialState);
  if (!buttonText.includes(expectedVersion)) {
    throw new Error(`Previous release did not advertise expected update ${expectedVersion}; button text=${JSON.stringify(buttonText)}`);
  }
  if (!['available', 'downloading', 'staging', 'ready'].includes(initialState || '')) {
    throw new Error(`Update affordance appeared in unexpected state: ${initialState}`);
  }

  await update.click({ noWaitAfter: true }).catch((error) => {
    if (!applicationClosed) throw error;
  });

  const deadline = Date.now() + 180_000;
  while (Date.now() < deadline && !applicationClosed) {
    await new Promise((resolve) => setTimeout(resolve, 1_000));
    try {
      const state = await update.getAttribute('data-state');
      if (state && observedStates.at(-1) !== state) observedStates.push(state);
      if (await page.getByTestId('desktop-update-progress').isVisible().catch(() => false)) sawProgressIndicator = true;
    } catch {
      if (applicationClosed) break;
    }
  }

  if (!applicationClosed && !observedStates.some((state) => ['downloading', 'staging', 'ready'].includes(state))) {
    throw new Error(`Clicking the update control did not start an updater transition; states=${observedStates.join(',')}`);
  }

  if (observedStates.includes('downloading') && !sawProgressIndicator) {
    throw new Error(`Updater entered downloading state without exposing progress UI; states=${observedStates.join(',')}`);
  }
  if (!applicationClosed) {
    throw new Error(`One update click did not automatically close the previous app for installation; states=${observedStates.join(',')}`);
  }

  await writeFile(evidencePath, `${JSON.stringify({
    expectedVersion,
    executablePath,
    buttonText,
    observedStates,
    applicationClosed,
    sawProgressIndicator,
    clicked: true,
    timestamp: new Date().toISOString(),
  }, null, 2)}\n`);
} finally {
  if (!applicationClosed) await app.close().catch(() => undefined);
}
