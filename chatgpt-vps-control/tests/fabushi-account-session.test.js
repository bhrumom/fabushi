import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { createFabushiAccountSessionStore } from "../lib/fabushi-account-session.js";

function response(payload, status = 200) {
  return new Response(JSON.stringify(payload), { status, headers: { "content-type": "application/json" } });
}

test("Fabushi CI account session logs in, stores credentials privately, and refreshes before reconnect", async () => {
  const root = await mkdtemp(join(tmpdir(), "fabushi-session-"));
  const sessionPath = join(root, "session.json");
  let timestamp = 1_000_000;
  const calls = [];
  const store = createFabushiAccountSessionStore({
    sessionPath,
    baseUrl: "https://api.example.test",
    now: () => timestamp,
    fetchImpl: async (url, init) => {
      const body = JSON.parse(init.body);
      calls.push({ url, body });
      if (url.endsWith("/api/auth/login")) {
        return response({
          accessToken: "a".repeat(48), refreshToken: "r".repeat(48), deviceId: body.deviceId,
          accessTokenExpiresAt: Math.floor(timestamp / 1000) + 900,
          refreshTokenExpiresAt: Math.floor(timestamp / 1000) + 86400,
          sessionId: "session-1", username: body.username, userId: "user-1",
        });
      }
      return response({
        accessToken: "b".repeat(48), refreshToken: "s".repeat(48), deviceId: body.deviceId,
        accessTokenExpiresAt: Math.floor(timestamp / 1000) + 900,
        refreshTokenExpiresAt: Math.floor(timestamp / 1000) + 86400,
        sessionId: "session-2", username: "runner", userId: "user-1",
      });
    },
  });
  try {
    const loggedIn = await store.login({ username: "runner", password: "not-logged", deviceId: "gha-1" });
    assert.equal(loggedIn.accessToken, "a".repeat(48));
    assert.deepEqual(calls[0].body, { username: "runner", password: "not-logged", deviceId: "gha-1" });
    assert.equal((await stat(sessionPath)).mode & 0o777, 0o600);
    assert.doesNotMatch(await readFile(sessionPath, "utf8"), /not-logged/);
    assert.equal(await store.accessToken(), "a".repeat(48));
    timestamp += 850_000;
    assert.equal(await store.accessToken(), "b".repeat(48));
    assert.deepEqual(calls[1].body, { refreshToken: "r".repeat(48), deviceId: "gha-1" });
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
