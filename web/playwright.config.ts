import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env['E2E_BASE_URL'] || 'http://localhost:4200';

export default defineConfig({
  testDir: './e2e',
  testMatch: '**/*.e2e.ts',
  fullyParallel: true,
  workers: 1,
  forbidOnly: !!process.env['CI'],
  retries: 0,
  timeout: 60_000,
  globalTimeout: 300_000,
  expect: { timeout: 10_000 },
  reporter: 'list',
  use: {
    baseURL,
    actionTimeout: 10_000,
    navigationTimeout: 20_000,
    timezoneId: 'UTC',
    // OAuth credentials and bearer tokens must not enter recorded artifacts.
    trace: 'off',
    screenshot: 'off',
    video: 'off',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  // An explicit URL means the caller manages the running stack, including in CI.
  webServer: process.env['E2E_BASE_URL']
    ? undefined
    : {
        command: 'npm start',
        url: baseURL,
        reuseExistingServer: !process.env['CI'],
        timeout: 120_000,
      },
});
