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
    await expect(numbers.nth(0)).toHaveText('3');   // game sources
    await expect(numbers.nth(1)).toHaveText('9');   // tactical motifs
    await expect(numbers.nth(2)).toHaveText('5');   // move grades
    // Guide count grows as guides are added — just check it's a number
    await expect(numbers.nth(3)).toHaveText(/^\d+$/);
    await expect(page.locator('.stat-label').nth(3)).toContainText(/GUIDES/i);
  });

  test('"Built by a student chess player" note is visible', async ({ page }) => {
    await expect(page.locator('.stats-note')).toContainText(/Built by a student chess player/i);
  });

  test('all five feature panels are present', async ({ page }) => {
    const features = page.locator('.feature');
    await expect(features).toHaveCount(5);
    await expect(features.nth(0)).toContainText(/AI-POWERED/i);
    await expect(features.nth(0)).toContainText(/IMPORT/i);
    await expect(features.nth(1)).toContainText(/REAL/i);
    await expect(features.nth(1)).toContainText(/ENGINE/i);
    await expect(features.nth(1)).toContainText(/ANALYSIS/i);
    await expect(features.nth(2)).toContainText(/TACTICAL/i);
    await expect(features.nth(2)).toContainText(/PATTERN RECOGNITION/i);
    await expect(features.nth(3)).toContainText(/CHESS\.COM & LICHESS/i);
    await expect(features.nth(4)).toContainText(/UNIFIED LIBRARY/i);
  });

  test('footer links to guides, about, sample analysis, contact, privacy and delete-account', async ({ page }) => {
    const footer = page.locator('footer');
    // Canonical URLs use a trailing slash
    const links = {
      'Chess Guides': '/guides/',
      'About': '/about/',
      'Sample Analysis': '/sample-analysis/',
      'Contact': '/contact/',
      'Privacy Policy': '/privacy/',
      'Delete My Account': '/delete-account/',
    };
    for (const [label, href] of Object.entries(links)) {
      await expect(footer.getByRole('link', { name: label, exact: true })).toHaveAttribute('href', href);
    }
    await expect(footer).toContainText('© 2026 ChessDiary');
  });

  test('no login/signup form fields are present on this page', async ({ page }) => {
    // The beta-signup form's email capture input is expected here — this
    // page is marketing-only, so the real login/signup screen (which has a
    // password field) must not be present. A password input is the
    // distinguishing signal of an actual auth form.
    await expect(page.locator('input[type="password"]')).toHaveCount(0);
  });

  test('AdSense script is loaded with the ChessDiary publisher ID', async ({ page }) => {
    // Added deliberately for AdSense site review (kept off the /app shell)
    const adsense = page.locator('script[src*="adsbygoogle"]');
    await expect(adsense).toHaveCount(1);
    await expect(adsense).toHaveAttribute('src', /client=ca-pub-1687484988403199/);
  });

  test('gtag analytics script is loaded', async ({ page }) => {
    const gtag = await page.locator('script[src*="googletagmanager.com/gtag/js"]').count();
    expect(gtag).toBeGreaterThan(0);
  });
});
