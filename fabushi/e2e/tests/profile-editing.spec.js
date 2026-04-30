import { test, expect } from '@playwright/test';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const requiredEnv = [
  'STAGING_APP_URL',
  'STAGING_TEST_LOGIN',
  'STAGING_TEST_PASSWORD',
  'STAGING_TEST_EMAIL',
  'STAGING_TEST_PHONE'
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

async function visibleBox(locator, timeout = 1500) {
  try {
    await locator.waitFor({ state: 'visible', timeout });
    return await locator.boundingBox({ timeout });
  } catch (_) {
    return null;
  }
}

async function clickVisible(locator, timeout = 1500) {
  try {
    await locator.waitFor({ state: 'visible', timeout });
    await locator.click({ timeout: 3000, force: true });
    return true;
  } catch (_) {
    return false;
  }
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

async function clickAgreementNearLoginButton(page) {
  const loginTextBox = await visibleBox(page.getByText('🔐 登录', { exact: true }).first(), 1200);
  const size = viewport(page);

  if (loginTextBox) {
    const loginCenterX = loginTextBox.x + loginTextBox.width / 2;
    const loginCenterY = loginTextBox.y + loginTextBox.height / 2;
    await page.mouse.click(Math.max(8, loginCenterX - 118), loginCenterY + 56);
    await page.waitForTimeout(700);
    await enableFlutterSemantics(page);
    return true;
  }

  const passwordBox = await visibleBox(page.getByPlaceholder(/请输入密码|密码|password/i).first(), 1000);
  if (passwordBox) {
    await page.mouse.click(
      Math.max(8, size.width / 2 - 118),
      passwordBox.y + passwordBox.height + 106
    );
    await page.waitForTimeout(700);
    await enableFlutterSemantics(page);
    return true;
  }

  return false;
}

async function acceptAgreement(page) {
  await enableFlutterSemantics(page);

  // The text label itself is not tappable in Flutter; the checkbox to its left
  // owns the GestureDetector. Prefer deriving the checkbox location from visible
  // agreement text instead of trusting Flutter Web's occasionally imprecise
  // generic semantics nodes.
  const agreementLabelLocators = [
    page.getByText('我已阅读并同意', { exact: true }).first(),
    page.getByText(/我已阅读并同意|我已阅读|同意.*协议|同意.*隐私|用户协议|隐私政策/i).first(),
    page.getByText(/agree|agreement|terms|privacy/i).first()
  ];

  for (const label of agreementLabelLocators) {
    const box = await visibleBox(label, 1200);
    if (box) {
      await page.mouse.click(Math.max(8, box.x - 18), box.y + box.height / 2);
      await page.waitForTimeout(700);
      await enableFlutterSemantics(page);
      return;
    }
  }

  if (await clickAgreementNearLoginButton(page)) return;

  const checkboxLocators = [
    page.getByRole('checkbox', { name: /我已阅读|同意|协议|隐私|agree|agreement|terms|privacy/i }).first(),
    page.getByRole('checkbox').first(),
    page.locator('[role="checkbox"]').first()
  ];

  for (const locator of checkboxLocators) {
    if (await clickVisible(locator, 1000)) {
      await page.waitForTimeout(700);
      await enableFlutterSemantics(page);
      return;
    }
  }

  const size = viewport(page);
  await page.mouse.click(Math.max(8, size.width / 2 - 118), size.height * 0.62);
  await page.waitForTimeout(700);
  await enableFlutterSemantics(page);
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

async function waitForPostLogin(page) {
  const timeout = 20000;
  const deadline = Date.now() + timeout;
  const authenticatedMarkers = [
    page.getByText('编辑资料', { exact: true }).first(),
    page.getByText('一门深入:', { exact: false }).first(),
    page.getByText('会员', { exact: true }).first(),
    page.getByText('历史', { exact: true }).first(),
    page.getByText('下载', { exact: true }).first()
  ];
  const loginFailure = page
    .getByText(/登录失败|密码错误|用户不存在|账号不存在|密码不正确|网络错误|服务器错误/)
    .first();
  let sawSuccessToast = false;

  while (Date.now() < deadline) {
    await enableFlutterSemantics(page);

    if (await loginFailure.isVisible().catch(() => false)) {
      const failureText = await loginFailure.textContent().catch(() => 'unknown login error');
      throw new Error(`Login failed before reaching profile screen: ${failureText}`);
    }

    if (await page.getByText('登录成功', { exact: false }).first().isVisible().catch(() => false)) {
      sawSuccessToast = true;
    }

    for (const marker of authenticatedMarkers) {
      if (await marker.isVisible().catch(() => false)) return;
    }

    if (sawSuccessToast) {
      const loginFormVisible = await page
        .getByPlaceholder('请输入用户名或邮箱')
        .first()
        .isVisible()
        .catch(() => false);
      if (!loginFormVisible) {
        await tapProfileTab(page);
        for (const marker of authenticatedMarkers) {
          if (await marker.isVisible().catch(() => false)) return;
        }
      }
    }

    await page.waitForTimeout(300);
  }

  throw new Error(
    `Timed out waiting for authenticated profile screen${
      sawSuccessToast ? ' after seeing the login success toast' : ''
    }`
  );
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

  test('logs in, updates profile, uploads avatar, and preserves stable login identifiers', async ({ page }, testInfo) => {
    const stableUsername = process.env.STAGING_TEST_LOGIN;
    const stableEmail = process.env.STAGING_TEST_EMAIL;
    const stablePhone = process.env.STAGING_TEST_PHONE;

    await page.goto('/', { waitUntil: 'networkidle' });
    await enableFlutterSemantics(page);

    await clickText(page, '我的', { fallback: 'profile-tab' });
    await ensureLoginForm(page);

    await fillByPlaceholderOrTap(page, '请输入用户名或邮箱', stableUsername, 0.41);
    await fillByPlaceholderOrTap(page, '请输入密码', process.env.STAGING_TEST_PASSWORD, 0.49);
    await acceptAgreement(page);
    await submitLogin(page);
    await waitForPostLogin(page);

    await clickText(page, '我的', { fallback: 'profile-tab' });
    await clickText(page, '编辑资料', { fallbackTap: [0.5, 0.48] });
    await expect(page.getByText('编辑资料', { exact: true })).toBeVisible({ timeout: 15000 });

    await fillByPlaceholderOrTap(page, '请输入用户名', stableUsername, 0.35);
    await fillByPlaceholderOrTap(page, '请输入邮箱', stableEmail, 0.43);
    await fillByPlaceholderOrTap(page, '请输入手机号', stablePhone, 0.51);

    const avatarPath = createTinyPng();
    const fileChooserPromise = page.waitForEvent('filechooser');
    await clickText(page, '点击从本地选择头像', { fallbackTap: [0.5, 0.23] });
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles(avatarPath);

    await clickText(page, '保存', { fallbackTap: [0.5, 0.86] });
    await expect(page.getByText('个人资料更新成功', { exact: false })).toBeVisible({ timeout: 15000 });

    await clickText(page, '我的', { fallback: 'profile-tab' });
    await expect(page.getByText(stableUsername, { exact: false })).toBeVisible({ timeout: 15000 });

    await testInfo.attach('updated-profile', {
      body: JSON.stringify({ stableUsername, stableEmail, stablePhone }, null, 2),
      contentType: 'application/json'
    });

    await page.reload({ waitUntil: 'networkidle' });
    await enableFlutterSemantics(page);
    await clickText(page, '我的', { fallback: 'profile-tab' });
    await expect(page.getByText(stableUsername, { exact: false })).toBeVisible({ timeout: 15000 });
  });
});
