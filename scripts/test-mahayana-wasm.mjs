import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const gluePath = resolve(repoRoot, 'fabushi/web/mahayana-wasm/mahayana_runtime.js');
const wasmPath = resolve(repoRoot, 'fabushi/web/mahayana-wasm/mahayana_runtime_bg.wasm');
const module = await import(pathToFileURL(gluePath));
const wasmBytes = await readFile(wasmPath);
await module.default({ module_or_path: wasmBytes });

const runtime = new module.MahayanaWebRuntime('{}');
try {
  const status = JSON.parse(runtime.execute(JSON.stringify({
    '@type': 'mahayana.runtime.status',
  })));
  if (
    status.ok !== true ||
    status.data.buildProfile !== 'web-wasm' ||
    status.data.remoteAgentEnabled !== false
  ) {
    throw new Error(`unexpected WASM status: ${JSON.stringify(status)}`);
  }
  const list = JSON.parse(runtime.execute(JSON.stringify({
    '@type': 'mahayana.conversation.list',
  })));
  if (!list.data.data.some((item) => item.id === 'codex:agent:assistant')) {
    throw new Error(`Codex contact missing: ${JSON.stringify(list)}`);
  }
  let rejectedWithoutLogin = false;
  try {
    runtime.execute(JSON.stringify({
      '@type': 'mahayana.conversation.send',
      conversationId: 'codex:agent:assistant',
      text: '你好',
    }));
  } catch {
    rejectedWithoutLogin = true;
  }
  if (!rejectedWithoutLogin) throw new Error('Web Agent accepted an unauthenticated request.');
  process.stdout.write(`${JSON.stringify({ ok: true, conversations: list.data.data.length })}\n`);
} finally {
  runtime.free();
}

