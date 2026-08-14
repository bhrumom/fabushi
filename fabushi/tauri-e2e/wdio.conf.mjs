import { spawn } from "node:child_process";
import { createWriteStream, existsSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";

const appBinaryPath = process.env.FABUSHI_TAURI_APP_BINARY;
if (!appBinaryPath) {
  throw new Error("FABUSHI_TAURI_APP_BINARY is required");
}
if (!existsSync(appBinaryPath)) {
  throw new Error(`Packaged Tauri executable does not exist: ${appBinaryPath}`);
}

const outputDir = resolve(process.env.FABUSHI_TAURI_E2E_OUTPUT_DIR || "wdio-output");
mkdirSync(outputDir, { recursive: true });

const embeddedPort = 4445;
let appProcess;
let appLog;
let spawnError;

const sleep = (ms) => new Promise((resolveSleep) => setTimeout(resolveSleep, ms));

async function waitForEmbeddedWebDriver(timeoutMs = 30_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (spawnError) throw spawnError;
    if (appProcess?.exitCode !== null && appProcess?.exitCode !== undefined) {
      throw new Error(`Packaged Tauri app exited before WebDriver became ready: ${appProcess.exitCode}`);
    }
    try {
      const response = await fetch(`http://127.0.0.1:${embeddedPort}/status`, {
        signal: AbortSignal.timeout(2_000),
      });
      if (response.ok) {
        const body = await response.json();
        if (body?.value?.ready === true) return;
      }
    } catch {
      // Embedded server is still starting.
    }
    await sleep(250);
  }
  throw new Error(`Embedded Tauri WebDriver was not ready on port ${embeddedPort}`);
}

async function stopPackagedApp() {
  if (!appProcess) return;
  if (appProcess.exitCode === null && appProcess.signalCode === null) {
    const exited = new Promise((resolveExit) => {
      const timer = setTimeout(() => resolveExit(false), 3_000);
      timer.unref();
      appProcess.once("exit", () => {
        clearTimeout(timer);
        resolveExit(true);
      });
    });
    appProcess.kill("SIGTERM");
    if (!(await exited) && appProcess.exitCode === null) {
      appProcess.kill("SIGKILL");
    }
  }
  appLog?.end();
  appProcess = undefined;
  appLog = undefined;
}

export const config = {
  runner: "local",
  specs: ["./test/specs/**/*.e2e.mjs"],
  maxInstances: 1,
  hostname: "127.0.0.1",
  port: embeddedPort,
  path: "/",
  capabilities: [{ browserName: "tauri" }],
  logLevel: "info",
  outputDir,
  bail: 0,
  waitforTimeout: 5_000,
  connectionRetryTimeout: 20_000,
  connectionRetryCount: 1,
  framework: "mocha",
  reporters: ["spec"],
  mochaOpts: {
    ui: "bdd",
    timeout: 60_000,
  },
  onPrepare: async () => {
    appLog = createWriteStream(resolve(outputDir, "packaged-app.log"), { flags: "w" });
    appProcess = spawn(appBinaryPath, [], {
      env: {
        ...process.env,
        TAURI_WEBDRIVER_PORT: String(embeddedPort),
        WDIO_EMBEDDED_SERVER: "true",
      },
      stdio: ["ignore", "pipe", "pipe"],
      detached: false,
    });
    appProcess.once("error", (error) => {
      spawnError = error;
    });
    appProcess.stdout?.pipe(appLog, { end: false });
    appProcess.stderr?.pipe(appLog, { end: false });
    try {
      await waitForEmbeddedWebDriver();
    } catch (error) {
      await stopPackagedApp();
      throw error;
    }
  },
  onComplete: async () => {
    await stopPackagedApp();
  },
};
