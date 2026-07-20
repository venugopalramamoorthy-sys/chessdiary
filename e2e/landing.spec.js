// Landing page tests — verifies the static marketing page at "/" renders
// correctly. This page is now plain static HTML (web/landing/index.html),
// not the Flutter app, so these use ordinary Playwright DOM selectors —
// no flt-semantics / waitForFlutter needed.
const { test, expect } = require('@playwright/test');

test.describe('Marketing landing page — static, at "/"', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('page title mentions ChessDiary', async ({ page }) => {
    await expect(page).toHaveTitle(/ChessDiary/i);
  });

  test('google-site-verification meta tag is present', async ({ page }) => {
    const content = await page
      .locator('head meta[name="google-site-verification"]')
      .getAttribute('content');
    expect(content).toBe('1TL2BCNrG9yYayIOVyYrR4alFXYu5XGbzR1_bOS4WKU');
  });

  test('header shows ChessDiary brand and Sign in link to /app', async ({ page }) => {
    await expect(page.locator('header .logo')).toContainText('CHESSDIARY');
    const signIn = page.locator('header .signin-link');
    await expect(signIn).toBeVisible();
    await expect(signIn).toHaveAttribute('href', '/app');
  });

  test('hero headline and CTA are visible, CTA links to /app', async ({ page }) => {
    await expect(page.locator('.hero h1')).toContainText(/blind spots/i);
    const cta = page.locator('.hero .arrow-link');
    await expect(cta).toContainText('Start Your Journey');
    await expect(cta).toHaveAttribute('href', '/app');
  });

  test('problem section headline is visible', async ({ page }) => {
    await expect(page.locator('.problem h2')).toContainText(/scattered/i);
    await expect(page.locator('.problem h2')).toContainText(/unexplained/i);
  });

  test('all four stats are visible', async ({ page }) => {
    const numbers = page.locator('.stat-number');
    await expect(numbers).toHaveCount(4);
    await expect(numbers.nth(0)).toContainText('∞');
    await expect(numbers.nth(1)).toContainText('100%');
    await expect(numbers.nth(2)).toContainText('8');
    await expect(numbers.nth(3)).toContainText('1');
  });

  test('"Built by a student chess player" note is visible', async ({ page }) => {
    await expect(page.locator('.stats-note')).toContainText(/Built by a student chess player/i);
  });

  test('all three feature panels are present', async ({ page }) => {
    const features = page.locator('.feature');
    await expect(features).toHaveCount(3);
    await expect(features.nth(0)).toContainText(/AI-POWERED/i);
    await expect(features.nth(0)).toContainText(/IMPORT/i);
    await expect(features.nth(1)).toContainText(/REAL/i);
    await expect(features.nth(1)).toContainText(/ENGINE/i);
    await expect(features.nth(1)).toContainText(/ANALYSIS/i);
    await expect(features.nth(2)).toContainText(/TACTICAL/i);
    await expect(features.nth(2)).toContainText(/PATTERN RECOGNITION/i);
  });

  test('footer has Chess Guides, Privacy Policy, and Delete My Account links', async ({ page }) => {
    const footer = page.locator('footer');
    await expect(footer.locator('a', { hasText: 'Chess Guides' })).toHaveAttribute('href', '/guides');
    await expect(footer.locator('a', { hasText: 'Privacy Policy' })).toHaveAttribute('href', '/privacy');
    await expect(footer.locator('a', { hasText: 'Delete My Account' })).toHaveAttribute('href', '/delete-account');
    await expect(footer).toContainText('© 2026 ChessDiary');
  });

  test('no login/signup form fields are present on this page', async ({ page }) => {
    // The beta-signup form's email capture input is expected here — this
    // page is marketing-only, so the real login/signup screen (which has a
    // password field) must not be present. A password input is the
    // distinguishing signal of an actual auth form.
    await expect(page.locator('input[type="password"]')).toHaveCount(0);
  });

  test('AdSense script is NOT loaded on this page', async ({ page }) => {
    const adsense = await page.locator('script[src*="adsbygoogle"]').count();
    expect(adsense).toBe(0);
  });

  test('gtag analytics script is loaded', async ({ page }) => {
    const gtag = await page.locator('script[src*="googletagmanager.com/gtag/js"]').count();
    expect(gtag).toBeGreaterThan(0);
  });
});
