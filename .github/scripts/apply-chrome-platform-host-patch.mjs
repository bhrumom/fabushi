import { readFile, writeFile } from "node:fs/promises";

const path = "desktop/electron/host-process.cjs";
let source = await readFile(path, "utf8");

function replaceOnce(from, to, label) {
  if (source.includes(to)) return;
  const index = source.indexOf(from);
  if (index < 0) throw new Error(`Chrome platform host patch marker missing: ${label}`);
  if (source.indexOf(from, index + from.length) >= 0) throw new Error(`Chrome platform host patch marker is ambiguous: ${label}`);
  source = source.replace(from, to);
}

replaceOnce(
  "const { createTestPlatformAccount } = require('./test-platform-account.cjs');",
  "const { createTestPlatformAccount } = require('./test-platform-account.cjs');\nconst { createChromePlatformServer } = require('./chrome-platform-server.cjs');",
  "platform server import",
);
replaceOnce(
  "    this.testPlatformAccount = this.env.FABUSHI_FEATURE_HOST_MODE === 'test'\n      ? createTestPlatformAccount({ app: this.app, fs: this.fs, now: this.now })\n      : null;",
  "    this.testPlatformAccount = this.env.FABUSHI_FEATURE_HOST_MODE === 'test'\n      ? createTestPlatformAccount({ app: this.app, fs: this.fs, now: this.now })\n      : null;\n    this.chromePlatformServer = createChromePlatformServer({\n      app: this.app,\n      env: this.env,\n      platform: this.platform,\n      hostRequest: (method, params, timeoutMs) => this.request(method, params, timeoutMs),\n    });",
  "platform server construction",
);
replaceOnce(
  "    this.child = child;\n    this.state = 'running';\n    this.startedAt = this.now();\n    this.emitLifecycle('running');",
  "    this.child = child;\n    this.state = 'running';\n    this.startedAt = this.now();\n    this.emitLifecycle('running');\n    void this.chromePlatformServer.start().catch((error) => {\n      console.error('[chrome-platform] desktop bridge failed to start', error);\n    });",
  "platform server start",
);
replaceOnce(
  "        resolve: (value) => { clearTimeout(timer); resolve(value); },",
  "        resolve: (value) => {\n          clearTimeout(timer);\n          if (method === 'feature.receive' && value) this.chromePlatformServer.broadcastEvent(value);\n          resolve(value);\n        },",
  "runtime event forwarding",
);
replaceOnce(
  "    child?.kill();\n    this.events.removeAllListeners();",
  "    child?.kill();\n    void this.chromePlatformServer.close().catch((error) => console.error('[chrome-platform] desktop bridge shutdown failed', error));\n    this.events.removeAllListeners();",
  "platform server shutdown",
);

await writeFile(path, source, "utf8");
console.log("Applied first-class Fabushi Chrome platform integration to desktop Host process.");
