import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const gluePath = resolve(
  repoRoot,
  'fabushi/web/telegram-wasm/fabushi_telegram.js',
);
const wasmPath = resolve(
  repoRoot,
  'fabushi/web/telegram-wasm/fabushi_telegram_bg.wasm',
);
const telegram = await import(pathToFileURL(gluePath));
const wasmBytes = await readFile(wasmPath);
await telegram.default({ module_or_path: wasmBytes });

const client = new telegram.TelegramWasmClient();
try {
  const status = JSON.parse(
    client.execute(
      JSON.stringify({ '@type': 'telegram.getStatus', '@extra': 'node-e2e' }),
    ),
  );
  if (
    status.ok !== true ||
    status.data.platform !== 'web' ||
    status.data['@extra'] !== 'node-e2e'
  ) {
    throw new Error(`unexpected WASM status: ${JSON.stringify(status)}`);
  }

  const authorization = JSON.parse(
    client.execute(
      JSON.stringify({
        '@type': 'telegram.executeAuthorizationCommand',
        command: { type: 'parametersAccepted' },
      }),
    ),
  );
  if (authorization.data.authorizationState.type !== 'waitPhoneNumber') {
    throw new Error(
      `unexpected authorization state: ${JSON.stringify(authorization)}`,
    );
  }

  process.stdout.write(
    `${JSON.stringify({
      ok: true,
      architecture: status.data.architecture,
      authorizationState: authorization.data.authorizationState.type,
    })}\n`,
  );
} finally {
  client.free();
}
