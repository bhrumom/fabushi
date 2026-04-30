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

function viewport(page) {
  return page.viewportSize() || { width: 390, height: 844 };
}

async function enableFlutterSemantics(page) {
  await page.evaluate(() => {
    const clickPlaceholder = (root) => {
      const placeholder = root.querySelector?.('flt-semantics-placeholder');
      if (placeholder) {
        placeholder.click();
        return true;
      }
      return false;
    };

    if (clickPlaceholder(document)) return true;
    for (const glassPane of document.querySelectorAll('flt-glass-pane')) {
      if (glassPane.shadowRoot && clickPlaceholder(glassPane.shadowRoot)) {
        return true;
      }
    }
    return false;
  }).catch(() => false);
  await page.waitForTimeout(500);
}

async function tap(page, xRatio, yRatio) {
  const size = viewport(page);
  await page.mouse.click(size.width * xRatio, size.height * yRatio);
  await page.waitForTimeout(700);
  await enableFlutterSemantics(page);
}

async function tapProfileTab(page) {
  const size = viewport(page);
  await page.mouse.click((size.width * 5) / 6, size.height - 35);
  await page.waitForTimeout(1200);
  await enableFlutterSemantics(page);
}

async function clickText(page, text, options = {}) {
  const exact = options.exact ?? true;
  await enableFlutterSemantics(page);
  const locator = page.getByText(text, { exact }).first();
  try {
    await locator.waitFor({ state: 'visible', timeout: options.timeout ?? 15000 });
    await locator.click();
  } catch (error) {
    if (options.fallback === 'profile-tab') {
      await tapProfileTab(page);
      return;
    }
    if (options.fallbackTap) {
      await tap(page, options.fallbackTap[0], options.fallbackTap[1]);
      return;
    }
    throw error;
  }
}

async function maybeClick(page, text) {
  await enableFlutterSemantics(page);
  const locator = page.getByText(text, { exact: true }).first();
  if (await locator.isVisible().catch(() => false)) {
    await locator.click();
    await page.waitForTimeout(700);
    await enableFlutterSemantics(page);
    return true;
  }
  return false;
}

async function ensureLoginForm(page) {
  await enableFlutterSemantics(page);
  if (await page.getByPlaceholder('请输入用户名或邮箱').first().isVisible({ timeout: 2500 }).catch(() => false)) return;
  await maybeClick(page, '立即登录 / 注册');
  if (await page.getByPlaceholder('请输入用户名或邮箱').first().isVisible({ timeout: 2500 }).catch(() => false)) return;
  await tap(page, 0.5, 0.72);
  if (await page.getByPlaceholder('请输入用户名或邮箱').first().isVisible({ timeout: 2500 }).catch(() => false)) return;
  await tap(page, 0.5, 0.62);
}

async function fillByPlaceholderOrTap(page, placeholder, value, yRatio) {
  await enableFlutterSemantics(page);
  const locator = page.getByPlaceholder(placeholder).first();
  if (await locator.isVisible({ timeout: 5000 }).catch(() => false)) {
    await locator.fill(value);
    return;
  }
  await tap(page, 0.5, yRatio);
  await page.keyboard.press('Control+A').catch(() => {});
  await page.keyboard.type(value, { delay: 10 });
}

async function acceptAgreement(page) {
  if (!(await maybeClick(page, '我已阅读并同意'))) {
    await tap(page, 0.34, 0.63);
  }
}

async function submitLogin(page) {
  await enableFlutterSemantics(page);
  const login = page.getByText('🔐 登录', { exact: true }).first();
  if (await login.isVisible().catch(() => false)) {
    await login.click();
  } else {
    await tap(page, 0.5, 0.55);
  }
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
    await enableFlutterSemantics(page);

    await clickText(page, '我的', { fallback: 'profile-tab' });
    await ensureLoginForm(page);

    await fillByPlaceholderOrTap(page, '请输入用户名或邮箱', process.env.STAGING_TEST_LOGIN, 0.41);
    await fillByPlaceholderOrTap(page, '请输入密码', process.env.STAGING_TEST_PASSWORD, 0.49);
    await acceptAgreement(page);
    await submitLogin(page);
    await expect(page.getByText('登录成功', { exact: false })).toBeVisible({ timeout: 20000 });

    await clickText(page, '我的', { fallback: 'profile-tab' });
    await clickText(page, '编辑资料', { fallbackTap: [0.5, 0.48] });
    await expect(page.getByText('编辑资料', { exact: true })).toBeVisible({ timeout: 15000 });

    await fillByPlaceholderOrTap(page, '请输入用户名', newUsername, 0.35);
    await fillByPlaceholderOrTap(page, '请输入邮箱', newEmail, 0.43);
    await fillByPlaceholderOrTap(page, '请输入手机号', newPhone, 0.51);

    const avatarPath = createTinyPng();
    const fileChooserPromise = page.waitForEvent('filechooser');
    await clickText(page, '点击从本地选择头像', { fallbackTap: [0.5, 0.23] });
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles(avatarPath);

    await clickText(page, '保存', { fallbackTap: [0.5, 0.86] });
    await expect(page.getByText('个人资料更新成功', { exact: false })).toBeVisible({ timeout: 15000 });

    await clickText(page, '我的', { fallback: 'profile-tab' });
    await expect(page.getByText(newUsername, { exact: false })).toBeVisible({ timeout: 15000 });

    await testInfo.attach('updated-profile', {
      body: JSON.stringify({ newUsername, newEmail, newPhone }, null, 2),
      contentType: 'application/json'
    });

    await page.reload({ waitUntil: 'networkidle' });
    await enableFlutterSemantics(page);
    await clickText(page, '我的', { fallback: 'profile-tab' });
    await expect(page.getByText(newUsername, { exact: false })).toBeVisible({ timeout: 15000 });
  });
});
