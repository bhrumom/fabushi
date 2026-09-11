import { defineConfig } from '@playwright/test';

// Presentation-only: real renderer, existing browser fixture transport, no native Host.
// The packaged Electron / Android / iOS acceptance workflows remain independent.
export default defineConfig({
  testDir: './headless',
  testMatch: '**/*.spec.ts',
  timeout: 45_000,
  expect: { timeout: 10_000 },
  fullyParallel: true,
  captureGitInfo: { commit: false, diff: false },
  forbidOnly: true,
  retries: 0,
  workers: 2,
  outputDir: '../.fast-ui-evidence/results',
  reporter: [['list'], ['json', { outputFile: '../.fast-ui-evidence/report/results.json' }],
    ['html', { outputFolder: '../.fast-ui-evidence/report', open: 'never' }]],
  use: {
    browserName: 'chromium',
    headless: true,
    baseURL: 'http://127.0.0.1:1420',
    viewport: { width: 1280, height: 900 },
    actionTimeout: 10_000,
    serviceWorkers: 'block',
    screenshot: 'on',
    video: 'on',
    trace: 'on',
  },
  webServer: {
    command: 'npm run dev',
    url: 'http://127.0.0.1:1420',
    reuseExistingServer: false,
    timeout: 60_000,
    stdout: 'pipe',
    stderr: 'pipe',
  },
});
