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

function safeProjectName(testInfo) {
  return testInfo.project.name.replace(/[^a-z0-9]+/gi, '-').replace(/^-|-$/g, '').toLowerCase();
}

test.describe('staging profile API flow', () => {
  test.describe.configure({ mode: 'serial' });

  test('logs in with username, email, and phone, then updates profile fields and exercises username rename rollback', async ({ request }, testInfo) => {
    for (const name of requiredEnv) env(name);

    const login = env('STAGING_TEST_LOGIN');
    const password = env('STAGING_TEST_PASSWORD');
    const email = env('STAGING_TEST_EMAIL');
    const phone = env('STAGING_TEST_PHONE');
    const projectMarker = `${safeProjectName(testInfo)}-${Date.now()}`;

    async function fetchUserInfo(token, contextLabel) {
      const response = await request.get(apiUrl('/api/auth/user-info'), {
        headers: { Authorization: `Bearer ${token}` }
      });
      expect(response.status(), `user-info failed for ${contextLabel}: ${await response.text()}`).toBe(200);
      return await response.json();
    }

    async function passwordLogin(identifier) {
      const response = await request.post(apiUrl('/api/auth/login'), {
        data: { username: identifier, password }
      });
      expect(response.status(), `login failed for ${identifier}: ${await response.text()}`).toBe(200);
      const body = await response.json();
      expect(body.token).toBeTruthy();
      const user = body.user ?? await fetchUserInfo(body.token, `login:${identifier}`);
      expect(user, 'login must inline user or allow immediate user-info fetch').toBeTruthy();
      return { token: body.token, user };
    }

    const usernameLogin = await passwordLogin(login);
    expect(usernameLogin.user?.username).toBe(login);

    const seedMarker = `ci-seed-${projectMarker}`;
    const seedProfile = await request.post(apiUrl('/api/auth/update-profile'), {
      headers: { Authorization: `Bearer ${usernameLogin.token}` },
      data: {
        username: login,
        email,
        phoneNumber: phone,
        avatar: `https://example.com/fabushi-e2e-avatar-${seedMarker}.png`
      }
    });
    expect(seedProfile.status(), await seedProfile.text()).toBe(200);
    const seeded = await seedProfile.json();
    expect(seeded.success).toBe(true);
    expect(seeded.user?.username).toBe(login);
    expect(seeded.user?.email).toBe(email);
    expect(seeded.user?.phoneNumber).toBe(phone);

    const seededToken = seeded.token || usernameLogin.token;

    await passwordLogin(email);
    await passwordLogin(phone);

    const before = await fetchUserInfo(seededToken, 'before-update');
    expect(before.username).toBe(login);
    expect(before.email).toBe(email);
    expect(before.phoneNumber).toBe(phone);
    expect(before.hasPassword).toBe(true);

    const marker = `ci-${projectMarker}`;
    const update = await request.post(apiUrl('/api/auth/update-profile'), {
      headers: { Authorization: `Bearer ${seededToken}` },
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

    const tokenAfterUpdate = updated.token || seededToken;
    const after = await fetchUserInfo(tokenAfterUpdate, 'after-update');
    expect(after.username).toBe(login);
    expect(after.email).toBe(email);
    expect(after.phoneNumber).toBe(phone);
    expect(after.avatar).toContain(marker);

    const renameSuffix = projectMarker.slice(-10);
    const trimmedLogin = login.slice(0, Math.max(2, 31 - renameSuffix.length));
    const renamedUsername = `${trimmedLogin}-${renameSuffix}`;

    const renameResponse = await request.post(apiUrl('/api/auth/update-profile'), {
      headers: { Authorization: `Bearer ${tokenAfterUpdate}` },
      data: {
        username: renamedUsername,
        email,
        phoneNumber: phone,
        avatar: `https://example.com/fabushi-e2e-avatar-rename-${projectMarker}.png`
      }
    });
    expect(renameResponse.status(), await renameResponse.text()).toBe(200);
    const renamed = await renameResponse.json();
    expect(renamed.success).toBe(true);
    expect(renamed.user?.username).toBe(renamedUsername);
    expect(renamed.token, 'username change should rotate a fresh token').toBeTruthy();

    const renamedToken = renamed.token;
    const renamedPayload = await fetchUserInfo(renamedToken, 'after-rename');
    expect(renamedPayload.username).toBe(renamedUsername);
    expect(renamedPayload.email).toBe(email);
    expect(renamedPayload.phoneNumber).toBe(phone);

    const renamedLogin = await passwordLogin(renamedUsername);
    expect(renamedLogin.user?.username).toBe(renamedUsername);
    await passwordLogin(email);
    await passwordLogin(phone);

    const rollbackResponse = await request.post(apiUrl('/api/auth/update-profile'), {
      headers: { Authorization: `Bearer ${renamedToken}` },
      data: {
        username: login,
        email,
        phoneNumber: phone,
        avatar: `https://example.com/fabushi-e2e-avatar-rollback-${projectMarker}.png`
      }
    });
    expect(rollbackResponse.status(), await rollbackResponse.text()).toBe(200);
    const rolledBack = await rollbackResponse.json();
    expect(rolledBack.success).toBe(true);
    expect(rolledBack.user?.username).toBe(login);
    expect(rolledBack.token, 'rolling back username should also issue a fresh token').toBeTruthy();

    const rollbackToken = rolledBack.token;
    const rollbackPayload = await fetchUserInfo(rollbackToken, 'after-rollback');
    expect(rollbackPayload.username).toBe(login);
    expect(rollbackPayload.email).toBe(email);
    expect(rollbackPayload.phoneNumber).toBe(phone);

    const finalUsernameLogin = await passwordLogin(login);
    expect(finalUsernameLogin.user?.username).toBe(login);
    await passwordLogin(email);
    await passwordLogin(phone);
  });
});
