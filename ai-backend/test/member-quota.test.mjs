import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const testDir = path.dirname(fileURLToPath(import.meta.url));

async function listen(server) {
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  return server.address().port;
}

function json(res, status, payload) {
  res.writeHead(status, { 'content-type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(payload));
}

async function readJsonBody(req) {
  let body = '';
  for await (const chunk of req) body += chunk;
  return body ? JSON.parse(body) : {};
}

async function startMockUpstreams() {
  const deepSeekRequests = [];
  const server = http.createServer(async (req, res) => {
    if (req.url === '/api/stripe/membership-status') {
      if (req.headers.authorization !== 'Bearer member-token') {
        json(res, 401, { success: false, error: 'invalid token' });
        return;
      }
      json(res, 200, {
        success: true,
        userId: 'member-1',
        username: 'member_user',
        membership: { type: 'paid', isActive: true },
      });
      return;
    }

    if (req.url === '/deepseek/chat/completions' && req.method === 'POST') {
      const body = await readJsonBody(req);
      deepSeekRequests.push(body);
      json(res, 200, {
        choices: [{ message: { content: '阿弥陀佛，测试通过。' } }],
        usage: {
          prompt_tokens: 3,
          completion_tokens: 2,
          total_tokens: 5,
        },
      });
      return;
    }

    json(res, 404, { success: false, error: `unhandled ${req.method} ${req.url}` });
  });

  const port = await listen(server);
  return {
    baseUrl: `http://127.0.0.1:${port}`,
    deepSeekBaseUrl: `http://127.0.0.1:${port}/deepseek`,
    deepSeekRequests,
    close: () => new Promise((resolve) => server.close(resolve)),
  };
}

async function waitForHealth(baseUrl) {
  let lastError;
  for (let i = 0; i < 80; i += 1) {
    try {
      const response = await fetch(`${baseUrl}/health`);
      if (response.ok) return;
      lastError = new Error(`health returned ${response.status}`);
    } catch (error) {
      lastError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw lastError || new Error('backend did not become healthy');
}

async function startAiBackend(upstreams) {
  const dataDir = await mkdtemp(path.join(os.tmpdir(), 'dacheng-ai-test-'));
  const portServer = http.createServer();
  const port = await listen(portServer);
  await new Promise((resolve) => portServer.close(resolve));

  const child = spawn(process.execPath, ['src/server.js'], {
    cwd: path.resolve(testDir, '..'),
    env: {
      ...process.env,
      PORT: String(port),
      DATA_DIR: dataDir,
      SQLITE_PATH: path.join(dataDir, 'test.sqlite'),
      DEEPSEEK_API_KEY: 'test-key',
      DEEPSEEK_BASE_URL: upstreams.deepSeekBaseUrl,
      FABUSHI_API_BASE_URL: upstreams.baseUrl,
      MEMBER_MONTHLY_TOKEN_LIMIT: '605',
      REQUIRE_MEMBER_FOR_AI: 'true',
      RATE_LIMIT_PER_MINUTE: '1000',
      LOG_LEVEL: 'fatal',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  let stderr = '';
  child.stderr.on('data', (chunk) => {
    stderr += chunk.toString();
  });

  const baseUrl = `http://127.0.0.1:${port}`;
  try {
    await waitForHealth(baseUrl);
  } catch (error) {
    child.kill('SIGTERM');
    throw new Error(`${error.message}\n${stderr}`);
  }

  return {
    baseUrl,
    close: async () => {
      child.kill('SIGTERM');
      await new Promise((resolve) => child.once('exit', resolve));
      await rm(dataDir, { recursive: true, force: true });
    },
  };
}

test('member AI quota is enforced server-side', async () => {
  const upstreams = await startMockUpstreams();
  const backend = await startAiBackend(upstreams);

  try {
    const spoofed = await fetch(`${backend.baseUrl}/api/ai/chat`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        message: 'hi',
        username: 'spoofed_member',
        clientMembershipHint: true,
      }),
    });
    assert.equal(spoofed.status, 403);
    const spoofedPayload = await spoofed.json();
    assert.match(spoofedPayload.message, /会员/);
    assert.equal(upstreams.deepSeekRequests.length, 0);

    const allowed = await fetch(`${backend.baseUrl}/api/ai/chat`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: 'Bearer member-token',
      },
      body: JSON.stringify({ message: 'hi' }),
    });
    assert.equal(allowed.status, 200);
    const allowedPayload = await allowed.json();
    assert.equal(allowedPayload.success, true);
    assert.equal(allowedPayload.usage.monthlyLimit, 605);
    assert.equal(allowedPayload.usage.remainingTokens, 600);
    assert.equal(upstreams.deepSeekRequests.length, 1);
    assert.equal(upstreams.deepSeekRequests[0].max_tokens, 604);

    const exhausted = await fetch(`${backend.baseUrl}/api/ai/chat`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: 'Bearer member-token',
      },
      body: JSON.stringify({ message: 'hi' }),
    });
    assert.equal(exhausted.status, 429);
    const exhaustedPayload = await exhausted.json();
    assert.match(exhaustedPayload.message, /token/);
    assert.equal(exhaustedPayload.details.remainingTokens, 600);
    assert.equal(upstreams.deepSeekRequests.length, 1);
  } finally {
    await backend.close();
    await upstreams.close();
  }
});
