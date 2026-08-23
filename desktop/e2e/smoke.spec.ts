import { _electron as electron, expect, test, type Page } from '@playwright/test';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const packagedExecutable = process.env.FABUSHI_ELECTRON_EXECUTABLE?.trim() || null;

async function launchDesktopApp(appDataDir: string) {
  return electron.launch({
    ...(packagedExecutable
      ? { executablePath: packagedExecutable, args: [] }
      : { args: [appRoot] }),
    env: {
      ...process.env,
      FABUSHI_APP_DATA: appDataDir,
      FABUSHI_FEATURE_HOST_MODE: process.env.FABUSHI_FEATURE_HOST_MODE || 'test',
      MAHAYANA_APP_HOST_BIN: process.env.MAHAYANA_APP_HOST_BIN || '',
    },
  });
}

async function completeBrowserLogin(page: Page): Promise<void> {
  while (await page.getByTestId('onboarding-gate').isVisible().catch(() => false)) {
    await page.getByTestId('onboarding-next').click();
  }
  const login = page.getByTestId('login-gate');
  if (await login.isVisible().catch(() => false)) {
    await page.getByTestId('browser-login-start').click();
    await expect(login).toBeHidden();
  }
  await expect(page.getByTestId('host-status')).toHaveAttribute('data-state', 'ready');
  await expect(page.getByTestId('messenger-workspace')).toBeVisible();
}

test('desktop package drives the unified Messenger through Electron IPC and the real Rust Host', async () => {
  const appDataDir = await mkdtemp(path.join(tmpdir(), 'fabushi-electron-e2e-'));
  const app = await launchDesktopApp(appDataDir);

  try {
    const page = await app.firstWindow();
    await expect(page.getByTestId('onboarding-gate')).toBeVisible();
    await expect(page.locator('.desktop-mode-switch')).toHaveCount(0);

    const security = await page.evaluate(() => ({
      nodeRequire: typeof (window as unknown as { require?: unknown }).require,
      processGlobal: typeof (window as unknown as { process?: unknown }).process,
      bridgeKeys: Object.keys(window.fabushi).sort(),
      mahayanaKeys: Object.keys(window.mahayana ?? {}).sort(),
    }));
    expect(security.nodeRequire).toBe('undefined');
    expect(security.processGlobal).toBe('undefined');
    expect(security.bridgeKeys).toEqual([
      'contractVersion',
      'notify',
      'openExternal',
      'openSystemSettings',
      'pickFile',
      'windowFocused',
    ]);
    expect(security.mahayanaKeys).toEqual(['contractVersion', 'invoke', 'subscribe']);

    const hostInfo = await page.evaluate(() => window.mahayana!.invoke<{
      platform: string;
      protocolVersion: string;
      runtimeVersion: string;
    }>('feature.info'));
    expect(hostInfo.platform).toBe('electron');
    expect(hostInfo.protocolVersion).not.toBe('');
    expect(hostInfo.runtimeVersion).toContain('test');

    await completeBrowserLogin(page);

    await test.step('unified conversation composer traverses the Host', async () => {
      const assistant = page.getByTestId('peer-legacy:conversation:codex:agent:assistant');
      await expect(assistant).toBeVisible();
      await assistant.click();
      const marker = `Electron Host smoke ${Date.now()}`;
      await page.getByTestId('messenger-input').fill(marker);
      await page.getByTestId('messenger-send').click();
      await expect(page.getByText(marker, { exact: true })).toBeVisible();
      await expect(page.getByText(`收到：${marker}`, { exact: true })).toBeVisible();
    });

    await test.step('Electron bridge executes a safe Host feature command', async () => {
      const accepted = await page.evaluate(() => window.mahayana!.invoke<{ requestId: string }>('feature.execute', {
        command: { type: 'capability.list', requestId: 'electron-smoke-capability-list' },
      }));
      expect(accepted.requestId).toBe('electron-smoke-capability-list');
    });

    await expect(page.getByTestId('host-status')).toHaveAttribute('data-state', 'ready');
    await expect(page.getByTestId('messenger-input')).toBeVisible();
  } finally {
    await app.close();
    await rm(appDataDir, { recursive: true, force: true });
  }
});
