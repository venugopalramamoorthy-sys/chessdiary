// Copies the plain static marketing pages from web/ into build/web/ so the
// local Firebase Hosting emulator (see playwright.config.js webServer)
// serves current source without requiring a full `flutter build web` on
// every test run. `flutter build web` copies these directories into
// build/web verbatim (no Dart compilation involved), so a plain file copy
// here is equivalent.
//
// Dart/Flutter app changes (main.dart.js, app-shell.html) are NOT covered —
// run `flutter build web` manually first if those changed.
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const PAGES = ['landing', 'privacy', 'delete-account', 'guides'];

for (const page of PAGES) {
  const src = path.join(ROOT, 'web', page);
  const dest = path.join(ROOT, 'build', 'web', page);
  fs.cpSync(src, dest, { recursive: true });
}

console.log(`Synced static pages into build/web: ${PAGES.join(', ')}`);
