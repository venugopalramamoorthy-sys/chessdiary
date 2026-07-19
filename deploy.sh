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

echo "Deploying to Firebase Hosting..."
firebase deploy --only hosting

echo "Done! Live at https://chessdiary.app"
