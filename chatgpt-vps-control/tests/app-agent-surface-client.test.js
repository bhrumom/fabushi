import assert from "node:assert/strict";
import { chmod, mkdtemp, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { AppAgentSurfaceUnavailableError, createAppAgentSurfaceClient } from "../lib/app-agent-surface-client.js";

const TOKEN = "a".repeat(64);

async function writeDiscovery(path, overrides = {}) {
  await writeFile(path, JSON.stringify({
    version: 1,
    appId: "fabushi.desktop",
    origin: "http://127.0.0.1:43199",
    token: TOKEN,
    pid: 123,
    ...overrides,
  }), { mode: 0o600 });
  await chmod(path, 0o600).catch(() => {});
}

test("App Agent Surface client reads a private discovery file and never sends credentials in the body", async () => {
  const root = await mkdtemp(join(tmpdir(), "fabushi-app-agent-client-"));
  const discoveryPath = join(root, "bridge.json");
  const calls = [];
  try {
    await writeDiscovery(discoveryPath);
    const client = createAppAgentSurfaceClient({
      discoveryPath,
      fetchImpl: async (url, init) => {
        calls.push({ url, init });
        return new Response(JSON.stringify({ ok: true, result: { available: true, generation: 4 } }), {
          status: 200,
          headers: { "content-type": "application/json" },
        });
      },
    });
    assert.deepEqual(await client.call("snapshot", { maxElements: 10 }), { available: true, generation: 4 });
    assert.equal(calls.length, 1);
    assert.equal(calls[0].url, "http://127.0.0.1:43199/v1/snapshot");
    assert.equal(calls[0].init.headers.Authorization, `Bearer ${TOKEN}`);
    assert.deepEqual(JSON.parse(calls[0].init.body), { input: { maxElements: 10 } });
    assert.equal(calls[0].init.body.includes(TOKEN), false);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("App Agent Surface client fails closed for missing, public, or symlink discovery", async () => {
  const root = await mkdtemp(join(tmpdir(), "fabushi-app-agent-client-deny-"));
  const missing = join(root, "missing.json");
  const publicFile = join(root, "public.json");
  const link = join(root, "link.json");
  try {
    const missingClient = createAppAgentSurfaceClient({ discoveryPath: missing, fetchImpl: async () => new Response() });
    assert.equal((await missingClient.status()).available, false);

    await writeDiscovery(publicFile, { origin: "https://example.com" });
    const publicClient = createAppAgentSurfaceClient({ discoveryPath: publicFile, fetchImpl: async () => new Response() });
    await assert.rejects(() => publicClient.call("status"), AppAgentSurfaceUnavailableError);

    await symlink(publicFile, link);
    const symlinkClient = createAppAgentSurfaceClient({ discoveryPath: link, fetchImpl: async () => new Response() });
    await assert.rejects(() => symlinkClient.call("status"), /discovery file is invalid/u);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
