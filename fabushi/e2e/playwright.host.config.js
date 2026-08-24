import { existsSync } from "node:fs";
import { defineConfig } from "@playwright/test";

const chromiumExecutable = [
  process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH,
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/Applications/Chromium.app/Contents/MacOS/Chromium",
  "/usr/bin/google-chrome",
  "/usr/bin/google-chrome-stable",
  "/usr/bin/chromium",
  "/usr/bin/chromium-browser",
].find((candidate) => candidate && existsSync(candidate));

export default defineConfig({
  testDir: "./tests",
  testMatch: "host-fast-user-journey.spec.ts",
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 1 : 0,
  workers: process.env.CI ? 2 : undefined,
  timeout: 30_000,
  expect: { timeout: 5_000 },
  reporter: [
    ["line"],
    ["html", { outputFolder: "playwright-report/host-fast", open: "never" }],
  ],
  use: {
    baseURL: "http://127.0.0.1:4173",
    reducedMotion: "reduce",
    launchOptions: chromiumExecutable
      ? { executablePath: chromiumExecutable }
      : undefined,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "off",
  },
  webServer: {
    // Exercise the exact production bundle consumed by Tauri instead of a
    // development-only transform pipeline.
    command:
      "cd ../../frontend && corepack pnpm --filter @fabushi/host build && corepack pnpm --filter @fabushi/host preview:e2e",
    url: "http://127.0.0.1:4173/",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    stdout: "pipe",
    stderr: "pipe",
  },
});
