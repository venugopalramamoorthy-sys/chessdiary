// Landing page tests — verifies the marketing sections, hero, and features
// render correctly before any login.
const { test, expect } = require('@playwright/test');
const { waitForFlutter, shot } = require('./helpers');

test.describe('Landing page — unauthenticated', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForFlutter(page);
    await shot(page, 'landing-initial');
  });

  test('page title is chessdiary', async ({ page }) => {
    await expect(page).toHaveTitle(/chessdiary/i);
  });

  test('nav bar shows ChessDiary brand name', async ({ page }) => {
    await expect(page.locator('flt-semantics', { hasText: 'ChessDiary' }).first()).toBeVisible();
  });

  test('Get started CTA is visible in nav', async ({ page }) => {
    await expect(page.locator('flt-semantics', { hasText: 'Get started' }).first()).toBeVisible();
  });

  test('hero headline "Every game." is visible', async ({ page }) => {
    await expect(page.locator('flt-semantics').filter({ hasText: /Every game/ }).first()).toBeVisible();
  });

  test('hero subheading mentions Chess.com', async ({ page }) => {
    const subheading = page.locator('flt-semantics').filter({ hasText: /Chess\.com/ }).first();
    await expect(subheading).toBeVisible();
  });

  test('PERSONAL CHESS JOURNAL eyebrow is visible', async ({ page }) => {
    const eyebrow = page.locator('flt-semantics').filter({ hasText: /PERSONAL CHESS JOURNAL/ }).first();
    await expect(eyebrow).toBeVisible();
  });

  test('analysis badges visible on chess board', async ({ page }) => {
    await expect(
      page.locator('flt-semantics').filter({ hasText: 'Blunder detected' }).first()
    ).toBeVisible();
    await expect(
      page.locator('flt-semantics').filter({ hasText: 'Stockfish analysis' }).first()
    ).toBeVisible();
    await shot(page, 'landing-hero-badges');
  });

  test('features section header visible after scroll', async ({ page }) => {
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight / 2));
    await page.waitForTimeout(800);
    await shot(page, 'landing-features-scroll');
    const header = page.locator('flt-semantics').filter({ hasText: /Everything you need/ }).first();
    await expect(header).toBeVisible({ timeout: 10_000 });
  });

  test('all 8 feature card titles are present in the DOM', async ({ page }) => {
    const featureTitles = [
      'AI-Powered Import',
      'Chess.com & Lichess Sync',
      'Real Engine Analysis',
      'Tactical Pattern Recognition',
      'Board Replay & Study Mode',
      'Opening Repertoire',
      'Opponent Database',
      'Progress Dashboard',
    ];
    // Scroll to features section
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight * 0.55));
    await page.waitForTimeout(1000);
    for (const title of featureTitles) {
      await expect(
        page.locator('flt-semantics').filter({ hasText: title }).first()
      ).toBeVisible({ timeout: 8_000 });
    }
    await shot(page, 'landing-all-features');
  });

  test('auth form is at the bottom of the page', async ({ page }) => {
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(800);
    await shot(page, 'landing-auth-form');
    await expect(
      page.locator('flt-semantics').filter({ hasText: 'Welcome back' }).first()
    ).toBeVisible({ timeout: 8_000 });
  });

  test('Get started CTA scrolls to auth form', async ({ page }) => {
    const cta = page.locator('flt-semantics').filter({ hasText: 'Get started' }).first();
    await cta.click();
    await page.waitForTimeout(1200); // scroll animation
    await shot(page, 'landing-after-cta-click');
    // Auth form should now be in view
    await expect(
      page.locator('flt-semantics').filter({ hasText: 'Welcome back' }).first()
    ).toBeVisible({ timeout: 8_000 });
  });

  test('footer shows Built by a student chess player', async ({ page }) => {
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(600);
    await expect(
      page.locator('flt-semantics').filter({ hasText: /Built by a student/ }).first()
    ).toBeVisible({ timeout: 8_000 });
  });
});
