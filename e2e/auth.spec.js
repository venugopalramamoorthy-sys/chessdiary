// Authentication tests — login, logout, signup screen.
// Runs against the Flutter app at /app/ using the dedicated test Firebase
// account (testuser@chessdiary.test).
const { test, expect } = require('@playwright/test');
const {
  openApp, button, text, field, typeInto, login, isHome, openSignOutDialog, shot,
  TEST_EMAIL,
} = require('./helpers');

test.describe('Authentication — login flow', () => {
  test('login screen shows email, password, Google and sign-up options', async ({ page }) => {
    await openApp(page);
    await shot(page, 'auth-login-screen');

    await expect(field(page, 'Email')).toBeVisible();
    await expect(field(page, 'Password')).toHaveAttribute('type', 'password');
    await expect(button(page, 'Login')).toBeVisible();
    await expect(button(page, /Continue with Google/)).toBeVisible();
    await expect(button(page, "Don't have an account? Sign Up")).toBeVisible();
  });

  test('email/password login → lands on home screen', async ({ page }) => {
    await login(page);
    await shot(page, 'auth-after-login');

    await expect(button(page, 'Add Game').first()).toBeVisible();
    await expect(button(page, /^Library\b/).first()).toBeVisible();
  });

  test('incorrect password shows error and stays on login', async ({ page }) => {
    await openApp(page);
    await typeInto(page, 'Email', TEST_EMAIL);
    await typeInto(page, 'Password', 'wrong-password-xyz');
    await button(page, 'Login').click();
    await shot(page, 'auth-wrong-password');

    await expect(text(page, /Login failed/)).toBeVisible({ timeout: 15_000 });
    await expect(field(page, 'Email')).toBeVisible();
  });

  test('Sign Up opens the create-account screen, Back returns to login', async ({ page }) => {
    await openApp(page);
    await button(page, "Don't have an account? Sign Up").click();
    await shot(page, 'auth-signup-screen');

    await expect(field(page, 'Your Name')).toBeVisible();
    await expect(field(page, 'Email')).toBeVisible();
    await expect(field(page, 'Password (min 6 chars)')).toBeVisible();
    await expect(button(page, 'Create Account')).toBeVisible();

    // Touch layouts expose the tooltip too, so the label reads "Back Back"
    await button(page, /^Back\b/).click();
    await expect(button(page, 'Login')).toBeVisible();
    await expect(field(page, 'Your Name')).toHaveCount(0);
  });
});

test.describe('Authentication — logout flow', () => {
  test.beforeEach(async ({ page }) => {
    await login(page);
  });

  test('sign-out asks for confirmation', async ({ page }) => {
    await openSignOutDialog(page);
    await shot(page, 'auth-logout-dialog');

    await expect(text(page, 'You can sign back in any time.')).toBeVisible();
    await expect(button(page, 'Cancel')).toBeVisible();
    await expect(button(page, 'Sign out')).toBeVisible();
  });

  test('confirm sign-out → returns to login screen', async ({ page }) => {
    await openSignOutDialog(page);
    await button(page, 'Sign out').click();
    await shot(page, 'auth-after-logout');

    await expect(field(page, 'Email')).toBeVisible({ timeout: 15_000 });
    await expect(button(page, 'Login')).toBeVisible();
  });

  test('Cancel keeps user logged in', async ({ page }) => {
    await openSignOutDialog(page);
    await button(page, 'Cancel').click();
    await shot(page, 'auth-cancel-logout');

    await expect(text(page, 'Sign out?')).toHaveCount(0);
    await isHome(page);
    await expect(button(page, 'Add Game').first()).toBeVisible();
  });
});
