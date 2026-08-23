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

const safeNativeReads = [
  'getDesktopEnvironment',
  'getWindowState',
  'getThemeState',
  'getHardwareAcceleration',
  'getWebauthnProxyEnabled',
  'getUpdateStatus',
  'getComputeMigrationStatus',
  'getOnboardingSeen',
  'getTimeZone',
  'getAutoReviewInstructions',
  'getLocalToolPermission',
  'getLocalToolPermissionCeiling',
  'getSidebarCollapsed',
  'getExperimentsSnapshot',
  'getAgentDefaultModel',
  'getComputerUseModel',
  'getHostPinnedAgents',
  'getHostSidebarSections',
  'getAvailableModels',
  'getOfflineAsrStatus',
  'getReviewPreferences',
  'getPrivacyModeEnabled',
  'getRuntimeAccess',
  'listSecrets',
  'requestDiskSaverAudit',
  'getMcpState',
  'getEffectivePlugins',
  'getMcpCatalog',
  'getMcpTeamPopularity',
  'getProductionComputeAttachmentStatus',
] as const;

test('installed desktop exposes unified Messenger surfaces and safe native reads', async () => {
  const appDataDir = await mkdtemp(path.join(tmpdir(), 'fabushi-surface-e2e-'));
  const app = await launchDesktopApp(appDataDir);

  try {
    const page = await app.firstWindow();
    await expect(page.getByTestId('onboarding-gate')).toBeVisible();

    await test.step('browser auth lifecycle remains secret-free', async () => {
      const lifecycle = await page.evaluate(async () => {
        const start = await window.mahayana!.invoke<Record<string, unknown>>('feature.auth.browserStart');
        const attemptId = String(start.attemptId ?? '');
        const reopen = await window.mahayana!.invoke<Record<string, unknown>>('feature.auth.browserReopen', { attemptId });
        const cancel = await window.mahayana!.invoke<Record<string, unknown>>('feature.auth.browserCancel', { attemptId });
        return { start, reopen, cancel };
      });
      expect(String(lifecycle.start.attemptId ?? '')).not.toBe('');
      expect(lifecycle.start.pollSecret).toBeUndefined();
      expect(lifecycle.start.accessToken).toBeUndefined();
      expect(lifecycle.reopen.status).toBe('pending');
      expect(lifecycle.reopen.pollSecret).toBeUndefined();
      expect(lifecycle.cancel.status).toBe('cancelled');
    });

    await completeBrowserLogin(page);

    await test.step('single Messenger shell exposes the Telegram-class product sections', async () => {
      for (const title of [
        '聊天',
        '联系人',
        'Bots',
        '群组',
        '频道',
        '通话',
        '收藏',
        '归档',
        '文件夹',
        'Mini Apps',
        '支付',
        '设置',
      ]) {
        await expect(page.getByTitle(title)).toBeVisible();
      }
      await expect(page.locator('.desktop-mode-switch')).toHaveCount(0);
    });

    await test.step('chat peers expose an in-viewport composer', async () => {
      const peer = page.locator('[data-testid^="peer-"]').first();
      await expect(peer).toBeVisible();
      await peer.click();
      const input = page.getByTestId('messenger-input');
      await expect(input).toBeVisible();
      const box = await input.boundingBox();
      const viewport = await page.evaluate(() => ({ width: window.innerWidth, height: window.innerHeight }));
      expect(box).not.toBeNull();
      if (box) {
        expect(box.x + box.width).toBeLessThanOrEqual(viewport.width);
        expect(box.y + box.height).toBeLessThanOrEqual(viewport.height);
      }
    });

    await test.step('safe native desktop reads execute in the installed package', async () => {
      const results = await page.evaluate(async (methods) => {
        const bridge = (window as any).fabushiNative;
        const output: Record<string, { ok: boolean; value?: unknown; error?: string }> = {};
        for (const method of methods) {
          try {
            output[method] = { ok: true, value: await bridge.invoke(method, {}) };
          } catch (error) {
            output[method] = { ok: false, error: error instanceof Error ? error.message : String(error) };
          }
        }
        return output;
      }, [...safeNativeReads]);
      const failures = Object.entries(results).filter(([, result]) => !result.ok);
      expect(failures, JSON.stringify(failures, null, 2)).toEqual([]);
      const asr = results.getOfflineAsrStatus.value as { binaryPath?: string; available?: boolean };
      if (packagedExecutable) {
        const asrExecutable = process.platform === 'win32' ? 'whisper-cli.exe' : 'whisper-cli';
        const asrPath = String(asr.binaryPath ?? '').replaceAll('\\', '/');
        expect(asrPath).toContain(`/asr/${process.platform}-${process.arch}/${asrExecutable}`);
      } else {
        expect(results.getOfflineAsrStatus.ok).toBe(true);
      }
    });
  } finally {
    await app.close();
    await rm(appDataDir, { recursive: true, force: true });
  }
});
