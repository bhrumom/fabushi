import { defineConfig } from "@playwright/test";

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
    // GitHub's Ubuntu image already ships Google Chrome. Reusing it removes the
    // 20+ second Playwright container pull while keeping the browser version
    // explicit in the runner image release metadata.
    channel: process.env.CI ? "chrome" : undefined,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "off",
  },
  webServer: {
    command:
      "cd ../../frontend/apps/web && node ./node_modules/next/dist/bin/next dev --hostname 127.0.0.1 --port 4173",
    url: "http://127.0.0.1:4173/host",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    stdout: "pipe",
    stderr: "pipe",
  },
});
