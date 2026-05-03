import { test, expect } from '@playwright/test';

const baseUrl = process.env.STAGING_APP_URL;
const testUser = process.env.STAGING_TEST_LOGIN;
const testPassword = process.env.STAGING_TEST_PASSWORD;

test.describe('Staging Social and Privacy API', () => {
  let authToken: string;

  test.beforeAll(async ({ request }) => {
    // 登录获取 token
    const resp = await request.post(`${baseUrl}/api/auth/login`, {
      data: { username: testUser, password: testPassword },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    authToken = body.token;
  });

  test('toggle follow/unfollow', async ({ request }) => {
    const resp = await request.post(`${baseUrl}/api/social/follow/toggle`, {
      data: { username: 'alice' },
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body).toHaveProperty('success', true);
  });

  test('fetch follow list', async ({ request }) => {
    const resp = await request.get(`${baseUrl}/api/social/follows?type=following&username=${testUser}`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(Array.isArray(body.users)).toBe(true);
  });

  test('fetch follow summary', async ({ request }) => {
    const resp = await request.get(`${baseUrl}/api/social/follow-summary?username=${testUser}`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body).toHaveProperty('followerCount');
    expect(body).toHaveProperty('followingCount');
  });

  test('practice privacy GET and UPDATE', async ({ request }) => {
    // GET
    const getResp = await request.get(`${baseUrl}/api/social/practice-privacy`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(getResp.ok()).toBeTruthy();
    const privacy = await getResp.json();
    expect(privacy).toHaveProperty('isPrivate');

    // POST
    const postResp = await request.post(`${baseUrl}/api/social/practice-privacy`, {
      headers: { Authorization: `Bearer ${authToken}` },
      data: {
        isPrivate: true,
        showPracticeName: false,
        showDuration: true,
        showChantCount: false,
      },
    });
    expect(postResp.ok()).toBeTruthy();
    const updated = await postResp.json();
    expect(updated).toHaveProperty('success', true);
  });

  test('leaderboard practice records respect privacy', async ({ request }) => {
    const resp = await request.get(`${baseUrl}/api/leaderboard/practice`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    for (const entry of body.entries) {
      if (entry.privacy.isPrivate) {
        expect(entry.totalDuration).toBeNull();
        expect(entry.totalCount).toBeNull();
        expect(entry.latestSutra).toBeNull();
      }
    }
  });

  test('leaderboard records endpoint hides notes/remarks', async ({ request }) => {
    const resp = await request.get(`${baseUrl}/api/leaderboard/records`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    for (const rec of body.records) {
      expect(rec).not.toHaveProperty('notes');
      expect(rec).not.toHaveProperty('remark');
    }
  });
});