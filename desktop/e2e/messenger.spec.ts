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
  await expect(page.getByTestId('login-gate')).toBeVisible();
  await page.getByTestId('browser-login-start').click();
  await expect(page.getByTestId('login-gate')).toBeHidden();
  await expect(page.getByTestId('host-status')).toHaveAttribute('data-state', 'ready');
}

async function openMessenger(page: Page): Promise<void> {
  await page.getByTestId('open-messenger').click();
  await expect(page.getByTestId('messenger-workspace')).toBeVisible();
  await expect(page.getByTitle('聊天')).toBeVisible();
}

test('desktop Messenger exposes Telegram-class navigation and sends through the Rust Host', async () => {
  const appDataDir = await mkdtemp(path.join(tmpdir(), 'fabushi-messenger-e2e-'));
  const app = await launchDesktopApp(appDataDir);

  try {
    const page = await app.firstWindow();
    await completeBrowserLogin(page);
    await openMessenger(page);

    for (const label of [
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
      await expect(page.getByTitle(label)).toBeVisible();
    }

    const assistant = page.getByTestId('peer-conversation:codex:agent:assistant');
    await expect(assistant).toBeVisible();
    await assistant.click();
    await expect(page.getByTestId('messenger-input')).toBeVisible();

    await page.getByTestId('messenger-input').fill('统一消息链路验收');
    await page.getByTestId('messenger-send').click();
    await expect(page.getByText('收到：统一消息链路验收')).toBeVisible();

    await page.getByTitle('置顶').click();
    await expect(page.getByTitle('取消置顶')).toBeVisible();
    await page.getByTitle('静音').click();
    await expect(page.getByTitle('开启通知')).toBeVisible();

    await page.getByTitle('搜索当前会话').click();
    await expect(page.getByPlaceholder('在当前会话中搜索')).toBeVisible();
  } finally {
    await app.close();
    await rm(appDataDir, { recursive: true, force: true });
  }
});

test('desktop Messenger creates a real Bot collaboration group and sends into it', async () => {
  const appDataDir = await mkdtemp(path.join(tmpdir(), 'fabushi-messenger-group-e2e-'));
  const app = await launchDesktopApp(appDataDir);

  try {
    const page = await app.firstWindow();
    await completeBrowserLogin(page);
    await openMessenger(page);

    await page.getByRole('button', { name: '新建群组' }).first().click();
    await expect(page.getByText('联系人和 Bot 可以在同一群组中协作')).toBeVisible();
    await page.getByPlaceholder('群组名称').fill('人机协作验收群');

    const researchBot = page.getByRole('button', { name: /Research Bot/ });
    if (await researchBot.isVisible().catch(() => false)) await researchBot.click();
    await page.getByRole('button', { name: '创建群组' }).click();

    await expect(page.getByText('人机协作验收群')).toBeVisible();
    await page.getByText('人机协作验收群').click();
    await page.getByTestId('messenger-input').fill('群组消息链路验收');
    await page.getByTestId('messenger-send').click();
    await expect(page.getByText('群组消息链路验收')).toBeVisible();
  } finally {
    await app.close();
    await rm(appDataDir, { recursive: true, force: true });
  }
});

test('installed Mini App opens from the unified Messenger surface', async () => {
  const appDataDir = await mkdtemp(path.join(tmpdir(), 'fabushi-messenger-miniapp-e2e-'));
  const app = await launchDesktopApp(appDataDir);

  try {
    const page = await app.firstWindow();
    await completeBrowserLogin(page);

    await page.getByTestId('open-marketplace').click();
    const install = page.getByTestId('install-miniapp');
    if (await install.isEnabled()) await install.click();
    await expect(install).toBeDisabled();
    await page.getByRole('button', { name: '关闭插件市场' }).click();

    await openMessenger(page);
    await page.getByTitle('Mini Apps').click();
    await page.getByRole('button', { name: /全球法布施/ }).last().click();
    await expect(page.getByText('Mini App · 受控宿主容器')).toBeVisible();
    await expect(page.locator('iframe[title="global-dharma"]')).toBeVisible();
  } finally {
    await app.close();
    await rm(appDataDir, { recursive: true, force: true });
  }
});
