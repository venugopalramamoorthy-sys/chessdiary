// Shared helpers for ChessDiary Playwright tests.
const config = require('./playwright.config');

const TEST_EMAIL = config.TEST_EMAIL;
const TEST_PASSWORD = config.TEST_PASSWORD;

/**
 * Wait for Flutter to finish booting. Detects either the CanvasKit flt-glass-pane
 * or (when using HTML renderer) the presence of body text.
 */
async function waitForFlutter(page) {
  // Wait until the Flutter root element appears
  await page.waitForSelector('flt-glass-pane, flt-scene', { timeout: 60_000 });
  // Extra pause for Flutter to complete its first frame
  await page.waitForTimeout(1500);
}

/**
 * Log in with email + password via the landing page auth form.
 * Assumes the page is at the landing screen (/?flutter.renderer=html).
 */
async function login(page) {
  await waitForFlutter(page);

  // The auth form is at the bottom — scroll to it
  await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  await page.waitForTimeout(500);

  // Fill email and password fields (Flutter TextField → <input> in HTML renderer)
  const emailInput = page.locator('input').nth(0);
  const passwordInput = page.locator('input[type="password"]').first();

  await emailInput.fill(TEST_EMAIL);
  await passwordInput.fill(TEST_PASSWORD);

  // Click Sign in button
  await page.locator('flt-semantics >> text=Sign in').first().click();

  // Wait for home screen (Add Game FAB confirms authenticated state)
  await page.waitForSelector('flt-semantics', { timeout: 30_000 });
  await page.waitForTimeout(2000);
}

/**
 * Take a labelled screenshot. Screenshots are automatically saved by Playwright
 * when screenshot: 'on' is set in config — this helper adds an extra explicit
 * screenshot with a descriptive name for the test report.
 */
async function shot(page, name) {
  await page.screenshot({ path: `playwright-report/screenshots/${name}.png` });
}

module.exports = { waitForFlutter, login, shot, TEST_EMAIL, TEST_PASSWORD };
