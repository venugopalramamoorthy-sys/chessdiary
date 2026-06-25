#!/usr/bin/env bash
# ChessDiary deploy: build Flutter web release and push to Firebase Hosting
set -e

echo "Building Flutter web release..."
flutter build web --release

echo "Deploying to Firebase Hosting..."
firebase deploy --only hosting

echo "Done! Live at https://chessdiary.app"
