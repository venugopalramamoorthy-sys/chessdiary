# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is
**ChessDiary** — a Flutter Android app that lets a chess player upload photos/PDFs/screenshots of their game scoresheets (paper tournament games + online games from Chess.com/Lichess), uses AI to read the moves automatically, stores them all in one library, and analyses each game for blunders/mistakes.

## Current state
This is a **fully generated but not-yet-run** Flutter project. Every screen and service file already exists with working code. Nothing has been tested on a real device or emulator yet. Treat this as: "the code is written, now help me get it actually running and fix whatever breaks."

## Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter analyze          # Static analysis (linting)
flutter test             # Run all tests
flutter test test/foo_test.dart  # Run a single test file
flutter build apk        # Build release APK
```

For the Stockfish server (Python/Flask):
```bash
cd stockfish_server
pip install -r requirements.txt
python app.py            # Run locally on port 5000
```

## Tech stack
- **Frontend:** Flutter (Dart), Material 3, dark chess-themed UI
- **Auth + Database:** Firebase (Firebase Auth + Cloud Firestore)
- **AI scoresheet parsing + coaching tips:** Google Gemini 1.5 Flash (free tier)
- **AI game analysis (blunders/mistakes):** Stockfish chess engine, hosted as a small Python Flask server (`stockfish_server/`), deployed free on Render.com. Falls back to Gemini AI analysis if the Stockfish server isn't reachable.

## Architecture

### Service layer
- `gemini_service.dart` — calls Google Generative AI directly with API key; handles both scoresheet parsing (image/PDF/text → move list) and move-by-move game analysis/coaching
- `stockfish_service.dart` — calls the Render-hosted Flask server via HTTP POST to `/analyze` (accepts `{"pgn": "..."}`, returns `{"analysis": [...]}`) with GET `/health` for connectivity check; falls back to `gemini_service.dart` when unreachable
- `auth_service.dart` — thin wrapper around `FirebaseAuth.instance`
- `game_service.dart` — all Firestore CRUD under `users/{uid}/games/{gameId}`; also computes player stats

### Data flow for adding a game
`add_game_screen.dart` → user picks image/PDF/text → `gemini_service.parseMoves()` → user reviews parsed data → `game_service.saveGame()` → Firestore

### Data flow for game analysis
`game_detail_screen.dart` (Analysis tab) → `stockfish_service.analyzeGame()` → if server unreachable falls back to `gemini_service.analyzeGame()` → updates `MoveAnalysis` list stored in Firestore

### Key model
`game_model.dart` defines `ChessGame` (metadata + move list) and `MoveAnalysis` (per-move quality classification: best/good/inaccuracy/mistake/blunder)

## Configuration placeholders (must be filled before app runs)
1. `lib/services/gemini_service.dart` — replace `YOUR_GEMINI_API_KEY_HERE` (free key from Google AI Studio)
2. `lib/services/stockfish_service.dart` — replace `YOUR_RENDER_SERVER_URL_HERE` (URL after deploying `stockfish_server/` to Render.com)
3. `android/app/google-services.json` — **MISSING**; requires creating a Firebase project with package name `com.chessdiary.app`, enabling Email/Password auth + Firestore, and downloading this file

## Missing Android scaffolding
Only `android/app/src/main/AndroidManifest.xml` exists — the standard Android build files (`android/build.gradle`, `android/app/build.gradle`, etc.) were never generated. Run `flutter create .` in the project root first (back up and re-merge `AndroidManifest.xml` afterward), then add:
- `classpath 'com.google.gms:google-services:4.4.0'` to `android/build.gradle` dependencies
- `apply plugin: 'com.google.gms.google-services'` at the bottom of `android/app/build.gradle`
- `minSdkVersion 21` in `android/app/build.gradle`

## Known issues in generated code
- `add_game_screen.dart` has a stray line at the bottom (`get AuthService => null;`) — remove it; `AuthService` is already properly imported elsewhere in the file

## User's environment
- Windows PC with VS Code, Git, Android Studio (with AVD)
- Flutter SDK not yet installed; no Firebase/Gemini accounts set up yet
- 12th-grade student, personal project

## Known design decisions (don't "fix" these)
- Stockfish analysis falls back to Gemini automatically — intentional, not a bug
- Dark theme only, no light mode — intentional
- Android-only — iOS is a future possibility, not a current requirement
