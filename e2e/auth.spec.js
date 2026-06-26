// Authentication tests — login, logout, signup toggle.
// Uses the dedicated test Firebase account (testuser@chessdiary.test).
const { test, expect } = require('@playwright/test');
const { waitForFlutter, login, shot, TEST_EMAIL, TEST_PASSWORD } = require('./helpers');

test.describe('Authentication — login flow', () => {
  test('email/password login → lands on home screen', async ({ page }) => {
    await page.goto('/');
    await login(page);
    await shot(page, 'auth-after-login');

    // Home screen is confirmed by the Add Game FAB
    await expect(
      page.locator('flt-semantics').filter({ hasText: 'Add Game' }).first()
    ).toBeVisible({ timeout: 20_000 });
  });

  test('incorrect password shows error', async ({ page }) => {
    await page.goto('/');
    await waitForFlutter(page);
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(600);

    const emailInput = page.locator('input').nth(0);
    const passwordInput = page.locator('input[type="password"]').first();
    await emailInput.fill(TEST_EMAIL);
    await passwordInput.fill('wrong-password-xyz');

    await page.locator('flt-semantics').filter({ hasText: 'Sign in' }).first().click();
    await page.waitForTimeout(3000);
    await shot(page, 'auth-wrong-password');

    // An error snackbar or message should appear
    // (Firebase returns INVALID_PASSWORD or similar)
    await expect(
      page.locator('flt-semantics').filter({ hasText: /wrong-password|failed|invalid|error/i }).first()
    ).toBeVisible({ timeout: 10_000 });
  });

  test('signup form toggle shows name field', async ({ page }) => {
    await page.goto('/');
    await waitForFlutter(page);
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(600);
    await shot(page, 'auth-login-form');

    await page.locator('flt-semantics').filter({ hasText: "Don't have an account? Sign up" }).first().click();
    await page.waitForTimeout(500);
    await shot(page, 'auth-signup-form');

    await expect(
      page.locator('flt-semantics').filter({ hasText: 'Create your account' }).first()
    ).toBeVisible({ timeout: 5_000 });
    await expect(
      page.locator('input').nth(0) // name field appears first in signup
    ).toBeVisible();
  });

  test('signup toggle → back to login removes name field', async ({ page }) => {
    await page.goto('/');
    await waitForFlutter(page);
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(600);

    await page.locator('flt-semantics').filter({ hasText: "Don't have an account? Sign up" }).first().click();
    await page.waitForTimeout(400);
    await page.locator('flt-semantics').filter({ hasText: 'Already have an account? Sign in' }).first().click();
    await page.waitForTimeout(400);

    await expect(
      page.locator('flt-semantics').filter({ hasText: 'Welcome back' }).first()
    ).toBeVisible();
  });
});

test.describe('Authentication — logout flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await login(page);
  });

  test('logout button visible in home screen header', async ({ page }) => {
    // The logout icon (logout_rounded) should be in the header
    // In CanvasKit, look for the semantics label or screenshot it
    await shot(page, 'auth-home-header');
    // The logout button has tooltip "Sign out"
    await expect(
      page.locator('flt-semantics[aria-label="Sign out"]').first()
    ).toBeVisible({ timeout: 10_000 });
  });

  test('logout → confirmation dialog → confirm → returns to landing', async ({ page }) => {
    const logoutBtn = page.locator('flt-semantics[aria-label="Sign out"]').first();
    await logoutBtn.click();
    await page.waitForTimeout(800);
    await shot(page, 'auth-logout-dialog');

    // Confirmation dialog should appear
    await expect(
      page.locator('flt-semantics').filter({ hasText: 'Sign out?' }).first()
    ).toBeVisible({ timeout: 5_000 });

    // Click the "Sign out" confirm button
    await page.locator('flt-semantics').filter({ hasText: 'Sign out' }).last().click();
    await page.waitForTimeout(2000);
    await shot(page, 'auth-after-logout');

    // Should be back on landing screen
    await expect(
      page.locator('flt-semantics').filter({ hasText: 'Every game' }).first()
    ).toBeVisible({ timeout: 15_000 });
  });

  test('logout → Cancel keeps user logged in', async ({ page }) => {
    const logoutBtn = page.locator('flt-semantics[aria-label="Sign out"]').first();
    await logoutBtn.click();
    await page.waitForTimeout(800);

    await page.locator('flt-semantics').filter({ hasText: 'Cancel' }).first().click();
    await page.waitForTimeout(500);
    await shot(page, 'auth-cancel-logout');

    // Still on home screen
    await expect(
      page.locator('flt-semantics').filter({ hasText: 'Add Game' }).first()
    ).toBeVisible({ timeout: 5_000 });
  });
});
