import { test, expect } from '@playwright/test';

const apiBaseUrl = process.env.STAGING_API_URL;
const testUser = process.env.STAGING_TEST_LOGIN;
const testPassword = process.env.STAGING_TEST_PASSWORD;
const configuredSocialTarget = process.env.STAGING_SOCIAL_TARGET_USERNAME?.trim() || null;

test.describe('Staging Social and Privacy API', () => {
  let authToken: string | null = null;
  let loginUnavailableReason: string | null = null;
  let followTargetUsername: string | null = configuredSocialTarget;

  test.beforeAll(async ({ request }) => {
    const resp = await request.post(`${apiBaseUrl}/api/auth/login`, {
      data: { username: testUser, password: testPassword },
    });

    if (!resp.ok()) {
      loginUnavailableReason = `staging test account is unavailable: HTTP ${resp.status()} ${await resp.text()}`;
      return;
    }

    const body = await resp.json();
    authToken = body.token;

    if (!followTargetUsername) {
      const leaderboardResp = await request.get(`${apiBaseUrl}/api/leaderboard/practice`, {
        headers: { Authorization: `Bearer ${authToken}` },
      });
      expect(leaderboardResp.ok()).toBeTruthy();
      const leaderboardBody = await leaderboardResp.json();
      const entries = Array.isArray(leaderboardBody.leaderboard) ? leaderboardBody.leaderboard : [];
      const candidate = entries.find((entry: any) => entry?.username && entry.username !== testUser);
      followTargetUsername = candidate?.username || null;
    }
  });

  test.beforeEach(() => {
    test.skip(!authToken, loginUnavailableReason || 'staging test account is unavailable');
  });

  test('toggle follow/unfollow', async ({ request }) => {
    test.skip(!followTargetUsername, 'staging 环境暂无可关注的其他用户');

    const resp = await request.post(`${apiBaseUrl}/api/social/follow/toggle`, {
      data: { username: followTargetUsername },
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body).toHaveProperty('success', true);
    expect(body).toHaveProperty('username', followTargetUsername);
  });

  test('fetch follow list', async ({ request }) => {
    const resp = await request.get(`${apiBaseUrl}/api/social/follows?type=following&username=${testUser}`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(Array.isArray(body.users)).toBe(true);
  });

  test('fetch follow summary', async ({ request }) => {
    const resp = await request.get(`${apiBaseUrl}/api/social/follow-summary?username=${testUser}`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body).toHaveProperty('followerCount');
    expect(body).toHaveProperty('followingCount');
  });

  test('practice privacy GET and UPDATE', async ({ request }) => {
    const getResp = await request.get(`${apiBaseUrl}/api/social/practice-privacy`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(getResp.ok()).toBeTruthy();
    const getBody = await getResp.json();
    const privacy = getBody.privacy ?? getBody;
    expect(privacy).toHaveProperty('isPrivate');

    const postResp = await request.post(`${apiBaseUrl}/api/social/practice-privacy`, {
      headers: { Authorization: `Bearer ${authToken}` },
      data: {
        isPrivate: true,
        showPracticeName: false,
        showDuration: true,
        showChantCount: false,
      },
    });
    expect(postResp.ok()).toBeTruthy();
    const postBody = await postResp.json();
    expect(postBody).toHaveProperty('success', true);
    const updated = postBody.privacy ?? postBody;
    expect(updated).toHaveProperty('isPrivate', true);
  });

  test('leaderboard practice records respect privacy', async ({ request }) => {
    const resp = await request.get(`${apiBaseUrl}/api/leaderboard/practice`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    const entries = Array.isArray(body.leaderboard) ? body.leaderboard : [];

    for (const entry of entries) {
      if (entry.privacy?.isPrivate) {
        expect(entry.totalDuration).toBeNull();
        expect(entry.totalCount).toBeNull();
        expect(entry.latestSutra).toBeNull();
      }
    }
  });

  test('leaderboard records endpoint hides notes/remarks', async ({ request }) => {
    const practiceResp = await request.get(`${apiBaseUrl}/api/leaderboard/practice`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(practiceResp.ok()).toBeTruthy();
    const practiceBody = await practiceResp.json();
    const entries = Array.isArray(practiceBody.leaderboard) ? practiceBody.leaderboard : [];
    const publicEntry = entries.find((entry: any) => !entry.privacy?.isPrivate && entry.username);

    test.skip(!publicEntry, 'staging 环境暂无可用于公开记录校验的排行榜用户');

    const resp = await request.get(`${apiBaseUrl}/api/leaderboard/practice/records?username=${encodeURIComponent(publicEntry.username)}`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    const records = Array.isArray(body.records) ? body.records : [];

    for (const rec of records) {
      expect(rec).not.toHaveProperty('notes');
      expect(rec).not.toHaveProperty('remark');
      expect(rec).not.toHaveProperty('experience');
    }
  });
});
