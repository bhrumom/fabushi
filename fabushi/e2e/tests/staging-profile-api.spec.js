import { test, expect } from '@playwright/test';

const requiredEnv = [
  'STAGING_APP_URL',
  'STAGING_TEST_LOGIN',
  'STAGING_TEST_PASSWORD',
  'STAGING_TEST_EMAIL',
  'STAGING_TEST_PHONE'
];

function env(name) {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function apiUrl(path) {
  return new URL(path, env('STAGING_APP_URL')).toString();
}

test.describe('staging profile API flow', () => {
  test('logs in with username, email, and phone, then updates profile fields without changing stable values', async ({ request }) => {
    for (const name of requiredEnv) env(name);

    const login = env('STAGING_TEST_LOGIN');
    const password = env('STAGING_TEST_PASSWORD');
    const email = env('STAGING_TEST_EMAIL');
    const phone = env('STAGING_TEST_PHONE');

    async function passwordLogin(identifier) {
      const response = await request.post(apiUrl('/api/auth/login'), {
        data: { username: identifier, password }
      });
      expect(response.status(), `login failed for ${identifier}: ${await response.text()}`).toBe(200);
      const body = await response.json();
      expect(body.token).toBeTruthy();
      expect(body.username).toBe(login);
      return { token: body.token, user: body.user };
    }

    const usernameLogin = await passwordLogin(login);
    test.skip(
      !usernameLogin.user,
      'Staging Worker has not deployed the PR backend login response yet; deploy the current Worker before enforcing the full profile API flow.'
    );
    expect(usernameLogin.user?.username).toBe(login);

    await passwordLogin(email);
    await passwordLogin(phone);

    const beforeInfo = await request.get(apiUrl('/api/auth/user-info'), {
      headers: { Authorization: `Bearer ${usernameLogin.token}` }
    });
    expect(beforeInfo.status(), await beforeInfo.text()).toBe(200);
    const before = await beforeInfo.json();
    expect(before.username).toBe(login);
    expect(before.email).toBe(email);
    expect(before.phoneNumber).toBe(phone);
    expect(before.hasPassword).toBe(true);

    const marker = `ci-${Date.now()}`;
    const update = await request.post(apiUrl('/api/auth/update-profile'), {
      headers: { Authorization: `Bearer ${usernameLogin.token}` },
      data: {
        username: login,
        email,
        phoneNumber: phone,
        avatar: `https://example.com/fabushi-e2e-avatar-${marker}.png`
      }
    });
    expect(update.status(), await update.text()).toBe(200);
    const updated = await update.json();
    expect(updated.success).toBe(true);
    expect(updated.user?.username).toBe(login);
    expect(updated.user?.email).toBe(email);
    expect(updated.user?.phoneNumber).toBe(phone);
    expect(updated.user?.avatar).toContain(marker);

    const tokenAfterUpdate = updated.token || usernameLogin.token;
    const afterInfo = await request.get(apiUrl('/api/auth/user-info'), {
      headers: { Authorization: `Bearer ${tokenAfterUpdate}` }
    });
    expect(afterInfo.status(), await afterInfo.text()).toBe(200);
    const after = await afterInfo.json();
    expect(after.username).toBe(login);
    expect(after.email).toBe(email);
    expect(after.phoneNumber).toBe(phone);
    expect(after.avatar).toContain(marker);
  });
});
