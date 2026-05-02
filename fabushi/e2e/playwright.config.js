import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.STAGING_APP_URL || 'http://127.0.0.1:8080';
const ciStorageState = process.env.CI && process.env.STAGING_APP_URL
  ? 'eula-storage-state.json'
  : undefined;

export default defineConfig({
  testDir: './tests',
  timeout: 180000,
  expect: { timeout: 20000 },
  retries: process.env.CI ? 1 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? [['list'], ['html', { outputFolder: 'playwright-report', open: 'never' }]] : 'list',
  use: {
    baseURL,
    ...(ciStorageState ? { storageState: ciStorageState } : {}),
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    locale: 'zh-CN'
  },
  projects: [
    {
      name: 'web-chromium-desktop',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1280, height: 900 } }
    },
    {
      name: 'android-chrome-mobile',
      use: { ...devices['Pixel 7'] }
    },
    {
      name: 'ios-safari-mobile',
      use: { ...devices['iPhone 14'] }
    }
  ]
});
