// @ts-check
const { defineConfig, devices } = require('@playwright/test');

// Credentials for the dedicated test account (never use personal account).
// Set these in a .env file or as environment variables before running.
// TEST_EMAIL and TEST_PASSWORD should match a real Firebase account.
//
// Defaults match the Maestro test suite credentials.
const BASE_URL = process.env.BASE_URL || 'https://chessdiary.app';

// Force HTML renderer so Flutter renders real DOM elements (text, inputs,
// buttons) that Playwright can query. The production auto-build supports
// runtime renderer selection via query param.
const WEB_URL = `${BASE_URL}?flutter.renderer=html`;

module.exports = defineConfig({
  testDir: '.',
  timeout: 90_000,
  expect: { timeout: 20_000 },
  retries: process.env.CI ? 2 : 0,
  fullyParallel: false, // run sequentially — shared Firebase account
  reporter: [
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
    ['list'],
  ],
  use: {
    baseURL: WEB_URL,
    screenshot: 'on',
    video: 'retain-on-failure',
    trace: 'retain-on-failure',
    // Give Flutter time to boot on cold starts (Render free tier spins down)
    navigationTimeout: 60_000,
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 } },
    },
    {
      name: 'mobile',
      use: { ...devices['Pixel 5'], viewport: { width: 393, height: 851 } },
    },
  ],
});

// Export test URL so spec files can use it
module.exports.WEB_URL = WEB_URL;
module.exports.TEST_EMAIL = process.env.TEST_EMAIL || 'testuser@chessdiary.test';
module.exports.TEST_PASSWORD = process.env.TEST_PASSWORD || 'TestPass123!';
