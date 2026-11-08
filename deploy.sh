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
