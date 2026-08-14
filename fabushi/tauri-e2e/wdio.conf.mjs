import { existsSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";

const appBinaryPath = process.env.FABUSHI_TAURI_APP_BINARY;
if (!appBinaryPath) {
  throw new Error("FABUSHI_TAURI_APP_BINARY is required");
}
if (!existsSync(appBinaryPath)) {
  throw new Error(`Packaged Tauri executable does not exist: ${appBinaryPath}`);
}

const outputDir = resolve(process.env.FABUSHI_TAURI_E2E_OUTPUT_DIR || ".wdio-output");
mkdirSync(outputDir, { recursive: true });

export const config = {
  runner: "local",
  specs: ["./test/specs/**/*.e2e.mjs"],
  maxInstances: 1,
  services: [
    [
      "@wdio/tauri-service",
      {
        appBinaryPath,
        driverProvider: "embedded",
      },
    ],
  ],
  capabilities: [
    {
      browserName: "tauri",
      "tauri:options": {
        application: appBinaryPath,
      },
    },
  ],
  logLevel: "info",
  outputDir,
  bail: 0,
  waitforTimeout: 15_000,
  connectionRetryTimeout: 90_000,
  connectionRetryCount: 2,
  framework: "mocha",
  reporters: ["spec"],
  mochaOpts: {
    ui: "bdd",
    timeout: 60_000,
  },
};
