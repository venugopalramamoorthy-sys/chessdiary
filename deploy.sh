#!/usr/bin/env bash
# ChessDiary deploy: build Flutter web release and push to Firebase Hosting
set -e

echo "Building Flutter web release..."
flutter build web --release

# Firebase Hosting serves an exact static-file match before consulting
# rewrites, so the Flutter shell can't stay at build/web/index.html — that
# would always win over the "/" -> /landing/index.html rewrite. Renaming it
# frees up "/" for the static marketing page; the Flutter app keeps working
# under /app and /app/** via the renamed-file rewrites in firebase.json.
mv build/web/index.html build/web/app-shell.html

# Static pages for approved public game reports (/g/<slug>/, /games/, sitemap
# entries), read from Firestore with the Admin SDK. Every deploy replaces the
# whole site, so skipping this step would take published reports offline --
# it fails without serviceAccount.json unless you opt out explicitly.
if [ "${SKIP_PUBLIC_GAMES:-}" = "1" ]; then
  echo "SKIP_PUBLIC_GAMES=1: deploying WITHOUT public game report pages"
else
  echo "Building public game report pages..."
  [ -d tools/public-games/node_modules ] || (cd tools/public-games && npm ci --no-audit --no-fund)
  node tools/public-games/build.js --out build/web
fi

echo "Deploying to Firebase Hosting..."
firebase deploy --only hosting

echo "Done! Live at https://chessdiary.app"

# Deep check of the live site (browser tests, every page, security rules),
# reported to Telegram. It never fails the deploy -- the site is already
# live -- and is skipped where the test account / Telegram secrets aren't
# set up. SKIP_DEEP_CHECK=1 skips it.
if [ "${SKIP_DEEP_CHECK:-}" = "1" ]; then
  echo "SKIP_DEEP_CHECK=1: skipping the post-deploy deep check"
elif [ -f .env.test ] && [ -f healthcheck/secrets.json ] && [ -d e2e/node_modules ]; then
  echo "Running post-deploy deep check (about 5 minutes)..."
  sleep 20  # let the new version reach Firebase's CDN
  python healthcheck/deep_check.py --reason deploy \
    || echo "WARNING: post-deploy deep check found problems -- see the Telegram report above"
else
  echo "Skipping post-deploy deep check (needs .env.test, healthcheck/secrets.json and e2e/node_modules)"
fi
