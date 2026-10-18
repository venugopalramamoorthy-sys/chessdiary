// Shared helpers for ChessDiary Playwright tests.
const config = require('./playwright.config');

const APP_PATH = config.APP_PATH;
const TEST_EMAIL = config.TEST_EMAIL;
const TEST_PASSWORD = config.TEST_PASSWORD;

/**
 * Open the Flutter app and wait for it to boot. Flutter web draws to a
 * canvas, so we turn on its accessibility tree: that gives real <input>
 * elements (labelled via aria-label) and <flt-semantics role="button">
 * nodes whose text is the button label.
 */
async function openApp(page) {
  await page.goto(APP_PATH);
  await enableSemantics(page);
}

async function enableSemantics(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 60_000 });
  // Give Flutter time to finish its first frame before enabling semantics
  await page.waitForTimeout(2000);
  // Desktop Flutter enables semantics on a click of the placeholder; mobile
  // (touch) layouts want a pointer/touch tap instead, and either can ignore
  // the first attempt while still booting -- so send all of them and retry.
  for (let attempt = 0; attempt < 10; attempt++) {
    await page.evaluate(() => {
      const el = document.querySelector('flt-semantics-placeholder');
      if (!el) return;
      const r = el.getBoundingClientRect();
      const x = r.x + r.width / 2;
      const y = r.y + r.height / 2;
      const opts = { bubbles: true, clientX: x, clientY: y, pointerType: 'touch', isPrimary: true };
      el.dispatchEvent(new PointerEvent('pointerdown', opts));
      el.dispatchEvent(new PointerEvent('pointerup', opts));
      try {
        const touch = new Touch({ identifier: 1, target: el, clientX: x, clientY: y });
        el.dispatchEvent(new TouchEvent('touchstart', { bubbles: true, changedTouches: [touch] }));
        el.dispatchEvent(new TouchEvent('touchend', { bubbles: true, changedTouches: [touch] }));
      } catch (_) {
        // TouchEvent isn't constructible in non-touch contexts
      }
      el.click();
    });
    if (await page.locator('flt-semantics').count()) return;
    await page.waitForTimeout(1000);
  }
  throw new Error('Could not enable Flutter semantics');
}

/** A Flutter button, matched by its exact visible label. */
function button(page, label) {
  const text = label instanceof RegExp ? label : new RegExp(`^${escape(label)}$`);
  return page.locator('flt-semantics[role="button"]').filter({ hasText: text });
}

/** Any Flutter semantics node containing the given text. */
function text(page, value) {
  return page.locator('flt-semantics').filter({ hasText: value }).first();
}

/** A Flutter text field, matched by its label (e.g. "Email"). */
function field(page, label) {
  return page.locator(`input[aria-label="${label}"]`);
}

/**
 * Type into a Flutter text field like a user would. Playwright's fill() on
 * the semantics <input> can land before Flutter has attached its own
 * editing element, and the text is then silently dropped.
 */
async function typeInto(page, label, value) {
  const input = field(page, label);
  await input.click();
  await page.keyboard.press('ControlOrMeta+A');
  await page.keyboard.type(value);
}

function escape(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Open the app and log in with the dedicated test account.
 * Resolves once the home screen is showing.
 */
async function login(page) {
  await openApp(page);
  await typeInto(page, 'Email', TEST_EMAIL);
  await typeInto(page, 'Password', TEST_PASSWORD);
  await button(page, 'Login').click();
  await isHome(page);
}

/** Waits for the home screen (bottom nav "Home" tab confirms it). */
async function isHome(page) {
  await button(page, /^Home\b/).first().waitFor({ timeout: 30_000 });
}

/**
 * Open the account menu (avatar in the web header, "⋮" on narrow layouts)
 * and choose "Sign out", which shows the confirmation dialog.
 */
async function openSignOutDialog(page) {
  await button(page, /^Show menu/).first().click();
  // Web header menu labels it "SIGN OUT", the narrow-layout menu "Sign out"
  await page
    .locator('flt-semantics[role="menuitem"]')
    .and(page.locator('[aria-label="SIGN OUT"], [aria-label="Sign out"]'))
    .first()
    .click();
  await text(page, 'Sign out?').waitFor();
}

/**
 * Take a labelled screenshot. Screenshots are automatically saved by Playwright
 * when screenshot: 'on' is set in config — this helper adds an extra explicit
 * screenshot with a descriptive name for the test report.
 */
async function shot(page, name) {
  await page.screenshot({ path: `playwright-report/screenshots/${name}.png` });
}

module.exports = {
  openApp, enableSemantics, button, text, field, typeInto, login, isHome,
  openSignOutDialog, shot, TEST_EMAIL, TEST_PASSWORD,
};
