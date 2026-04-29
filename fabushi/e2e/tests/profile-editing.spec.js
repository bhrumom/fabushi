import { test, expect } from '@playwright/test';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const requiredEnv = [
  'STAGING_APP_URL',
  'STAGING_TEST_LOGIN',
  'STAGING_TEST_PASSWORD'
];

function missingEnv() {
  return requiredEnv.filter((name) => !process.env[name]);
}

async function clickText(page, text, options = {}) {
  const exact = options.exact ?? true;
  const locator = page.getByText(text, { exact }).first();
  await locator.waitFor({ state: 'visible' });
  await locator.click();
}

async function fillByPlaceholder(page, placeholder, value) {
  const locator = page.getByPlaceholder(placeholder).first();
  await locator.waitFor({ state: 'visible' });
  await locator.fill(value);
}

async function maybeClick(page, text) {
  const locator = page.getByText(text, { exact: true }).first();
  if (await locator.isVisible().catch(() => false)) {
    await locator.click();
    return true;
  }
  return false;
}

function createTinyPng() {
  const filePath = path.join(os.tmpdir(), `fabushi-avatar-${Date.now()}.png`);
  const pngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=';
  fs.writeFileSync(filePath, Buffer.from(pngBase64, 'base64'));
  return filePath;
}

test.describe('staging profile editing flow', () => {
  test.skip(({ }, testInfo) => {
    const missing = missingEnv();
    if (missing.length > 0) {
      testInfo.annotations.push({
        type: 'skip-reason',
        description: `Missing staging E2E environment variables: ${missing.join(', ')}`
      });
      return true;
    }
    return false;
  });

  test('logs in, updates profile, uploads avatar, and verifies login identifiers', async ({ page }, testInfo) => {
    const runId = process.env.GITHUB_RUN_ID || `${Date.now()}`;
    const suffix = `${runId}`.replace(/[^0-9a-zA-Z]/g, '').slice(-10);
    const newUsername = `e2e_${suffix}`;
    const newEmail = process.env.STAGING_TEST_EMAIL || `fabushi-e2e-${suffix}@example.com`;
    const newPhone = process.env.STAGING_TEST_PHONE || `+1555${suffix.padStart(10, '0').slice(-10)}`;

    await page.goto('/', { waitUntil: 'networkidle' });

    await clickText(page, '我的');
    await maybeClick(page, '立即登录 / 注册');

    await fillByPlaceholder(page, '请输入用户名或邮箱', process.env.STAGING_TEST_LOGIN);
    await fillByPlaceholder(page, '请输入密码', process.env.STAGING_TEST_PASSWORD);
    await clickText(page, '我已阅读并同意', { exact: false });
    await clickText(page, '🔐 登录');
    await expect(page.getByText('登录成功', { exact: false })).toBeVisible();

    await clickText(page, '我的');
    await clickText(page, '编辑资料');
    await expect(page.getByText('编辑资料', { exact: true })).toBeVisible();

    await page.getByPlaceholder('请输入用户名').fill(newUsername);
    await page.getByPlaceholder('请输入邮箱').fill(newEmail);
    await page.getByPlaceholder('请输入手机号').fill(newPhone);

    const avatarPath = createTinyPng();
    const fileChooserPromise = page.waitForEvent('filechooser');
    await clickText(page, '点击从本地选择头像');
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles(avatarPath);

    await clickText(page, '保存');
    await expect(page.getByText('个人资料更新成功', { exact: false })).toBeVisible();

    await clickText(page, '我的');
    await expect(page.getByText(newUsername, { exact: false })).toBeVisible();

    await testInfo.attach('updated-profile', {
      body: JSON.stringify({ newUsername, newEmail, newPhone }, null, 2),
      contentType: 'application/json'
    });

    await page.reload({ waitUntil: 'networkidle' });
    await clickText(page, '我的');
    await expect(page.getByText(newUsername, { exact: false })).toBeVisible();
  });
});
