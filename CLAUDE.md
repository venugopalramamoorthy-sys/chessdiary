# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is
**ChessDiary** — a Flutter app (Android + Web) that lets a chess player upload photos/PDFs/screenshots of their game scoresheets (paper tournament games + online games from Chess.com/Lichess), uses AI to read the moves automatically, stores them all in one library, and analyses each game for blunders/mistakes.

## Current state
The app is **live and working** on both platforms:
- **Web:** deployed at `chessdiary.app` (Firebase Hosting)
- **Android:** tested and running on Pixel 7a (Android 16, API 36)

## Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter run -d <device>  # Run on specific device (get IDs from `flutter devices`)
flutter analyze          # Static analysis (linting)
flutter test             # Run all tests
flutter build apk        # Build release APK
flutter build appbundle  # Build release AAB (for Play Store)
bash deploy.sh           # Build web release + deploy to chessdiary.app (Firebase Hosting)
```

For the Stockfish server (Python/Flask):
```bash
cd stockfish_server
pip install -r requirements.txt
python app.py            # Run locally on port 5000
```

## Tech stack
- **Frontend:** Flutter (Dart), Material 3, dark chess-themed UI
- **Platforms:** Android (primary) + Web (deployed at chessdiary.app)
- **Auth + Database:** Firebase (Firebase Auth — Email/Password + Google Sign-In; Cloud Firestore)
- **AI scoresheet parsing + coaching tips:** Google Gemini 1.5 Flash (free tier)
- **AI game analysis (blunders/mistakes):** Stockfish chess engine, hosted as a Python Flask server (`stockfish_server/`), deployed on Render.com. Falls back to Gemini AI analysis if the Stockfish server isn't reachable.

## Architecture

### Service layer
- `gemini_service.dart` — calls Google Generative AI directly with API key; handles both scoresheet parsing (image/PDF/text → move list) and move-by-move game analysis/coaching
- `stockfish_service.dart` — calls the Render-hosted Flask server via HTTP POST to `/analyze` (accepts `{"pgn": "..."}`, returns `{"analysis": [...]}`) with GET `/health` for connectivity check; falls back to `gemini_service.dart` when unreachable
- `auth_service.dart` — thin wrapper around `FirebaseAuth.instance`
- `game_service.dart` — all Firestore CRUD under `users/{uid}/games/{gameId}`; also computes player stats
- `account_link_service.dart` — handles linking/unlinking Chess.com and Lichess accounts to the user profile

### Data flow for adding a game
`add_game_screen.dart` → user picks image/PDF/text → `gemini_service.parseMoves()` → user reviews parsed data → `game_service.saveGame()` → Firestore

### Data flow for game analysis
`game_detail_screen.dart` (Analysis tab) → `stockfish_service.analyzeGame()` → if server unreachable falls back to `gemini_service.analyzeGame()` → updates `MoveAnalysis` list stored in Firestore

### Key model
`game_model.dart` defines `ChessGame` (metadata + move list) and `MoveAnalysis` (per-move quality classification: best/good/inaccuracy/mistake/blunder)

### Web theming
`lib/utils/web_theme.dart` (`WT` class) — web-specific theme helpers with dark-mode-aware dynamic getters (`WT.textColor`, `WT.mutedColor`, `WT.scaffoldBg`, `WT.altBg`). Use these instead of static `AppTheme.*` constants on web screens to ensure dark mode works. Never use `WT.*` inside `const` expressions — they are getters, not compile-time constants.

## Configuration — secrets NOT in this repo
These files must be obtained separately and placed locally before building:

1. **`android/app/google-services.json`** — download from Firebase Console → Project Settings → Android app. Required for Android builds.
2. **`android/key.properties`** + **`android/upload-keystore.jks`** — Android signing keys for Play Store release builds. Keep the keystore backed up; losing it means you can never update the Play Store app.
3. **`lib/services/gemini_service.dart`** — contains `apiKey` filled in with the actual Gemini API key (from Google AI Studio). Already set on the original dev machine.
4. **`lib/services/stockfish_service.dart`** — contains the Render.com server URL. Already set on the original dev machine.
5. **`lib/firebase_options.dart`** — contains Firebase config for web and Android. Already committed with real values (web config is safe to commit; Android values mirror google-services.json).

## Firebase project
- **Project:** `chessdiary-7f1e3`
- **Auth domain:** `chessdiary.app` (custom domain set in `firebase_options.dart`)
- **Authorized OAuth redirect:** `https://chessdiary.app/__/auth/handler` must be in the Google OAuth client's redirect URIs
- **Hosting:** Firebase Hosting at chessdiary.app + chessdiary-7f1e3.web.app

## Android build notes
- Package name: `com.chessdiary.app`
- Build files use Kotlin DSL (`.kts`)
- `minSdk` inherits from Flutter's default (21+)
- Google Services plugin is applied in `android/app/build.gradle.kts`
- Release signing config reads from `android/key.properties` (not committed)

## Known design decisions (don't "fix" these)
- Stockfish analysis falls back to Gemini automatically — intentional, not a bug
- Dark theme only, no light mode — intentional
- Web and Android share the same codebase; platform differences handled with `kIsWeb` guards
- `WT.offWhite` / `WT.cream` / `WT.ink` / `WT.muted` are legacy static constants — prefer the dynamic getters (`WT.scaffoldBg`, `WT.altBg`, `WT.textColor`, `WT.mutedColor`) in any new web code
