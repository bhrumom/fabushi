import { _electron as electron, expect, test, type ElectronApplication, type Locator, type Page, type TestInfo } from '@playwright/test';
import { copyFile, mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';

const packagedExecutable = process.env.FABUSHI_ELECTRON_EXECUTABLE?.trim() || '';
const referenceScreenshot = process.env.OBF_REFERENCE_SCREENSHOT?.trim() || '';
const realAcceptance = process.env.OBF_REAL_ACCEPTANCE === '1';
const visualThreshold = Number(process.env.OBF_MAX_DIFF_PIXEL_RATIO || '0.08');
const coworkers = [
  ['Chief', 'Chief of staff'],
  ['Research', 'Research and evidence'],
  ['Builder', 'Product engineering'],
  ['Launch', 'Go-to-market'],
] as const;

test.skip(!realAcceptance, 'OBF packaged acceptance runs only with OBF_REAL_ACCEPTANCE=1 against a real packaged Fabushi runtime.');

type LifecycleSample = { at: number; status: string; text: string };

async function launchPackaged(appDataDir: string, videoDir: string): Promise<ElectronApplication> {
  if (!packagedExecutable) throw new Error('FABUSHI_ELECTRON_EXECUTABLE is required for packaged acceptance');
  return electron.launch({
    executablePath: packagedExecutable,
    args: [],
    env: {
      ...process.env,
      FABUSHI_APP_DATA: appDataDir,
    },
    recordVideo: { dir: videoDir, size: { width: 1671, height: 937 } },
  });
}

async function completeLogin(page: Page): Promise<void> {
  type LoginPhase = 'onboarding' | 'login' | 'ready' | 'waiting';
  const readPhase = async (): Promise<LoginPhase> => {
    try {
      return await page.evaluate(() => {
        if (document.querySelector('[data-testid="onboarding-gate"]')) return 'onboarding';
        if (document.querySelector('[data-testid="login-gate"]')) return 'login';
        const messenger = document.querySelector('[data-testid="messenger-workspace"]');
        return messenger?.getAttribute('data-initial-host-hydrated') === 'true' ? 'ready' : 'waiting';
      }) as LoginPhase;
    } catch {
      return 'waiting';
    }
  };
  for (let attempt = 0; attempt < 12; attempt += 1) {
    await expect.poll(readPhase, { timeout: 15_000 }).not.toBe('waiting');
    const phase = await readPhase();
    if (phase === 'onboarding') {
      await page.getByTestId('onboarding-next').click();
      continue;
    }
    if (phase === 'login') {
      await page.getByTestId('browser-login-start').click();
      continue;
    }
    if (phase === 'ready') return;
  }
  throw new Error('Packaged Fabushi did not reach Messenger ready state');
}

async function setReferenceWindow(app: ElectronApplication, page: Page): Promise<void> {
  await app.evaluate(({ BrowserWindow }) => {
    const win = BrowserWindow.getAllWindows()[0];
    if (!win) throw new Error('Fabushi BrowserWindow missing');
    win.setContentSize(1671, 937, false);
    win.center();
  });
  await page.emulateMedia({ colorScheme: 'dark', reducedMotion: 'reduce' });
  await expect(page.getByTestId('messenger-workspace')).toBeVisible();
}

async function createCoworker(page: Page, name: string, description: string): Promise<void> {
  await page.evaluate(async ({ botName, botDescription }) => {
    if (!window.mahayana?.invoke) throw new Error('Mahayana bridge unavailable');
    const now = Date.now();
    await window.mahayana.invoke('feature.execute', {
      command: {
        type: 'bot.create',
        requestId: `obf-real-bot-create-${botName}-${now}`,
        name: botName,
        description: botDescription,
      },
    });
    await window.mahayana.invoke('feature.execute', {
      command: { type: 'bot.list', requestId: `obf-real-bot-list-${botName}-${now}` },
    });
  }, { botName: name, botDescription: description });
  await expect(peerByName(page, name)).toBeVisible({ timeout: 20_000 });
}

function peerByName(page: Page, name: string): Locator {
  return page.locator('[data-testid^="peer-legacy:bot:"]').filter({ hasText: name }).first();
}

async function botShape(locator: Locator): Promise<string> {
  const mark = locator.locator('[data-engine="fabushi-motion-v3"]').first();
  await expect(mark).toBeVisible();
  const shape = await mark.getAttribute('data-shape');
  expect(shape).toBeTruthy();
  return shape!;
}

async function installLifecycleJournal(page: Page): Promise<void> {
  await page.evaluate(() => {
    const scope = window as typeof window & { __obfLifecycle?: LifecycleSample[] };
    scope.__obfLifecycle = [];
    const sample = () => {
      for (const node of document.querySelectorAll<HTMLElement>('[class*="agentThinkingRow"]')) {
        const text = (node.innerText || '').trim();
        const seen = scope.__obfLifecycle?.some((entry) => entry.status === 'thinking' && entry.text === text);
        if (!seen) scope.__obfLifecycle?.push({ at: Date.now(), status: 'thinking', text });
      }
      for (const node of document.querySelectorAll<HTMLElement>('[data-testid="agent-step"]')) {
        const status = node.dataset.status || '';
        const text = (node.innerText || '').trim();
        const last = scope.__obfLifecycle?.at(-1);
        if (!last || last.status !== status || last.text !== text) scope.__obfLifecycle?.push({ at: Date.now(), status, text });
      }
    };
    sample();
    const observer = new MutationObserver(sample);
    observer.observe(document.documentElement, { subtree: true, attributes: true, childList: true, characterData: true });
    (scope as typeof scope & { __obfObserver?: MutationObserver }).__obfObserver = observer;
  });
}

async function sendRealTurn(page: Page, prompt: string): Promise<string> {
  const before = await page.locator('article[class*="messagePeer"]').count();
  await page.getByTestId('messenger-input').fill(prompt);
  await page.getByTestId('messenger-send').click();
  await expect(page.getByRole('article').filter({ hasText: prompt }).last()).toBeVisible({ timeout: 5_000 });
  const workbench = page.getByTestId('agent-workbench');
  await expect(workbench).toBeVisible({ timeout: 30_000 });
  const run = page.getByTestId('agent-run').last();
  await expect(run).toHaveAttribute('data-status', 'completed', { timeout: 180_000 });
  await expect.poll(async () => page.locator('article[class*="messagePeer"]').count(), { timeout: 30_000 }).toBeGreaterThan(before);
  const finalMessage = page.locator('article[class*="messagePeer"]').last();
  await expect(finalMessage).toBeVisible();
  return (await finalMessage.innerText()).trim();
}

async function attachFile(page: Page, filePath: string): Promise<void> {
  await page.getByTitle('附件').click();
  await page.getByRole('button', { name: '文件' }).click();
  const fileInput = page.locator('form input[type="file"]:not([accept])');
  await fileInput.setInputFiles(filePath);
  await expect(page.getByRole('article').filter({ hasText: path.basename(filePath) }).last()).toBeVisible({ timeout: 20_000 });
}

async function saveRuntimeEvidence(page: Page, testInfo: TestInfo): Promise<void> {
  const evidenceDir = testInfo.outputPath('obf-runtime');
  await mkdir(evidenceDir, { recursive: true });
  const lifecycle = await page.evaluate(() => (window as typeof window & { __obfLifecycle?: LifecycleSample[] }).__obfLifecycle || []);
  await writeFile(path.join(evidenceDir, 'lifecycle.json'), JSON.stringify(lifecycle, null, 2));
  const workbench = await page.evaluate(() => window.localStorage.getItem('fabushi.desktop.mahayana-agent-workbench.v1'));
  await writeFile(path.join(evidenceDir, 'mahayana-agent-workbench.json'), workbench || '{}');
  await page.screenshot({ path: path.join(evidenceDir, 'fabushi-openbot-comparison.png'), fullPage: false });
}

test('OBF exact packaged reference journey uses real Mahayana events and stays within the visual threshold', async ({}, testInfo) => {
  test.setTimeout(12 * 60_000);
  if (!referenceScreenshot) throw new Error('OBF_REFERENCE_SCREENSHOT is required; static or synthetic replacement is forbidden');
  const referenceBytes = await readFile(referenceScreenshot);
  if (referenceBytes.length < 10_000) throw new Error('OBF reference screenshot is unexpectedly small');

  const appDataDir = await mkdtemp(path.join(tmpdir(), 'fabushi-obf-real-'));
  const fixtureDir = await mkdtemp(path.join(tmpdir(), 'fabushi-obf-fixture-'));
  const csvPath = path.join(fixtureDir, 'launch-metrics.csv');
  const briefPath = path.join(fixtureDir, 'launch-brief.md');
  await writeFile(csvPath, 'metric,value\nclaims_verified,7/8\nrollback_ready,true\n');
  let app: ElectronApplication | null = null;
  let page: Page | null = null;
  let tracingActive = false;
  const evidenceDir = testInfo.outputPath('obf-runtime');
  const tracePath = path.join(evidenceDir, 'trace.zip');
  const videoDir = path.join(evidenceDir, 'video');
  await mkdir(videoDir, { recursive: true });
  try {
    app = await launchPackaged(appDataDir, videoDir);
    page = await app.firstWindow();
    await page.context().tracing.start({ screenshots: true, snapshots: true, sources: true });
    tracingActive = true;
    await completeLogin(page);
    await setReferenceWindow(app, page);
    await installLifecycleJournal(page);

    for (const [name, description] of coworkers) await createCoworker(page, name, description);
    for (const [name] of coworkers) await expect(peerByName(page, name)).toBeVisible();

    const chiefRosterShape = await botShape(peerByName(page, 'Chief'));

    await peerByName(page, 'Research').click();
    const research = await sendRealTurn(page,
      'Use at least one available read-only browser or research tool to verify a harmless public fact. Return a concise evidence note and clearly state which tool was used.');

    await peerByName(page, 'Builder').click();
    const builder = await sendRealTurn(page,
      "Use an available local shell or file tool to perform a harmless readiness check (for example printf 'rollback-ready'). Return a concise rollout note and the observed result.");

    await peerByName(page, 'Launch').click();
    const launch = await sendRealTurn(page,
      "Use the file-read tool (not a shell command) to read the exact missing path /tmp/fabushi-obf-intentionally-missing so the tool itself returns an error; then recover and return a concise launch note. Do not create, modify, or delete anything.");

    await writeFile(briefPath, ['# Coworker launch notes', '', `Research: ${research}`, '', `Builder: ${builder}`, '', `Launch: ${launch}`].join('\n'));

    await peerByName(page, 'Chief').click();
    await expect(page.locator('[class*="chatIdentity"] [data-engine="fabushi-motion-v3"]').first()).toHaveAttribute('data-shape', chiefRosterShape);
    await attachFile(page, briefPath);
    await attachFile(page, csvPath);

    const chiefPrompt = [
      'Synthesize these real coworker outputs into the final launch brief. Do not invent a new runtime or tool result.',
      `Research note: ${research}`,
      `Builder note: ${builder}`,
      `Launch note: ${launch}`,
      'Your final response MUST contain a heading exactly "Final launch brief", then a Markdown table with exactly the columns Workstream | Owner | Status and exactly three rows for Evidence/Research, Rollout/Builder, Release/Launch.',
      'After the table include a line exactly beginning "Source files:" and include `launch-brief.md` and `launch-metrics.csv` so Fabushi renders source-file chips.',
    ].join('\n\n');
    await sendRealTurn(page, chiefPrompt);

    const structured = page.getByTestId('structured-message-body').last();
    await expect(structured).toContainText('Final launch brief');
    const table = structured.getByTestId('assistant-result-table');
    await expect(table).toBeVisible();
    await expect(table.locator('th')).toHaveCount(3);
    await expect(table.locator('th').nth(0)).toHaveText('Workstream');
    await expect(table.locator('th').nth(1)).toHaveText('Owner');
    await expect(table.locator('th').nth(2)).toHaveText('Status');
    await expect(table.locator('tbody tr')).toHaveCount(3);
    await expect(table.getByTestId('assistant-owner-chip')).toHaveCount(3);
    await expect(structured.getByTestId('assistant-source-files')).toContainText('launch-brief.md');
    await expect(structured.getByTestId('assistant-source-files')).toContainText('launch-metrics.csv');

    const finalArticle = structured.locator('xpath=ancestor::article[1]');
    await expect(finalArticle.locator('[data-engine="fabushi-motion-v3"]').first()).toHaveAttribute('data-shape', chiefRosterShape);
    await finalArticle.hover();
    await expect(finalArticle.getByTestId('message-hover-actions')).toBeVisible();
    await expect(page.getByTestId('messenger-input')).toBeVisible();

    const lifecycle = await page.evaluate(() => (window as typeof window & { __obfLifecycle?: LifecycleSample[] }).__obfLifecycle || []);
    expect(lifecycle.some((sample) => sample.status === 'thinking')).toBeTruthy();
    expect(lifecycle.some((sample) => sample.status === 'running')).toBeTruthy();
    expect(lifecycle.some((sample) => sample.status === 'completed')).toBeTruthy();
    expect(lifecycle.some((sample) => sample.status === 'failed')).toBeTruthy();

    await saveRuntimeEvidence(page, testInfo);
    await page.context().tracing.stop({ path: tracePath });
    tracingActive = false;

    const expectedPath = testInfo.snapshotPath('openbot-reference-app.png');
    await mkdir(path.dirname(expectedPath), { recursive: true });
    await copyFile(referenceScreenshot, expectedPath);
    await expect(page.getByTestId('messenger-workspace')).toHaveScreenshot('openbot-reference-app.png', {
      animations: 'disabled',
      caret: 'hide',
      threshold: 0.15,
      maxDiffPixelRatio: visualThreshold,
    });

    await app.close();
    app = null;

    app = await launchPackaged(appDataDir, videoDir);
    page = await app.firstWindow();
    await completeLogin(page);
    await setReferenceWindow(app, page);
    const restoredChief = peerByName(page, 'Chief');
    await expect(restoredChief).toBeVisible({ timeout: 30_000 });
    await expect(restoredChief.locator('[data-engine="fabushi-motion-v3"]').first()).toHaveAttribute('data-shape', chiefRosterShape);
  } catch (error) {
    if (page) await saveRuntimeEvidence(page, testInfo).catch(() => undefined);
    throw error;
  } finally {
    if (tracingActive && page) {
      await page.context().tracing.stop({ path: tracePath }).catch(() => undefined);
    }
    await app?.close().catch(() => undefined);
    await rm(appDataDir, { recursive: true, force: true });
    await rm(fixtureDir, { recursive: true, force: true });
  }
});
