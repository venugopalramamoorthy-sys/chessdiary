# ♟ ChessDiary

**Your personal chess game journal, powered by Gemini AI.**

Log tournament games (paper scoresheets), online games (PDFs/screenshots), and get AI analysis — all in one place.

---

## Features
- 📸 **AI Scoresheet Parser** — Take a photo of your paper scoresheet or upload a PDF/screenshot. Gemini AI reads every move automatically.
- 📚 **Game Library** — All your games from any source, searchable and filterable.
- 🔍 **AI Game Analysis** — Gemini identifies blunders, mistakes, inaccuracies, and good moves with explanations.
- 📈 **Progress Tracking** — Win rate, game stats, favourite openings, source breakdown.
- 🤖 **AI Coach Insight** — Personalised coaching tips based on your recent games.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| Auth + Database | Firebase (Firestore + Auth) |
| AI Parsing + Analysis | Google Gemini 1.5 Flash (FREE tier) |

---

## Setup Guide (Step by Step)

### Step 1 — Install Flutter
Download Flutter SDK from https://flutter.dev/docs/get-started/install  
Add Flutter to your PATH and run:
```bash
flutter doctor
```
Make sure Android toolchain shows ✅

---

### Step 2 — Get your FREE Gemini API Key
1. Go to https://aistudio.google.com/app/apikey
2. Click "Create API Key"
3. Copy the key

Open `lib/services/gemini_service.dart` and replace:
```dart
static const String _apiKey = 'YOUR_GEMINI_API_KEY_HERE';
```
with your actual key.

**Free tier limits:**
- 15 requests/minute
- 1,500 requests/day
- $0 cost

---

### Step 3 — Set up Firebase
1. Go to https://console.firebase.google.com
2. Click "Add Project" → name it "chessdiary"
3. Enable **Authentication** → Email/Password
4. Enable **Firestore Database** → Start in test mode
5. Click the Android icon to add your app:
   - Package name: `com.chessdiary.app`
   - Download `google-services.json`
   - Place it at: `android/app/google-services.json`

---

### Step 4 — Configure Android build files

**android/build.gradle** — add in `dependencies {}`:
```gradle
classpath 'com.google.gms:google-services:4.4.0'
```

**android/app/build.gradle** — add at the bottom:
```gradle
apply plugin: 'com.google.gms.google-services'
```

Also set `minSdkVersion 21` in `android/app/build.gradle`.

---

### Step 5 — Firestore Security Rules
In Firebase Console → Firestore → Rules, paste:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

### Step 6 — Deploy the Stockfish Analysis Server (FREE)

This gives you **real chess engine analysis** (actual centipawn evaluation) instead of AI guesswork, for the blunder/mistake/best-move detection.

1. Go to https://render.com and sign up (free, no credit card needed)
2. Click **New +** → **Web Service**
3. Choose **"Build and deploy from a Git repository"**
   - Push the `stockfish_server/` folder to a new GitHub repo first (Render needs a repo to deploy from)
4. Render will detect `render.yaml` automatically — just click **Apply**
5. Wait 3-5 minutes for the first deploy
6. Copy your live URL, e.g. `https://chessdiary-stockfish.onrender.com`
7. Open `lib/services/stockfish_service.dart` and replace:
   ```dart
   static const String _baseUrl = 'YOUR_RENDER_SERVER_URL_HERE';
   ```
   with your actual URL.

**Note:** Free Render servers "sleep" after 15 minutes of no use. The first analysis request after sleeping takes ~20-30 seconds to wake up — this is normal and only happens once per session. The app automatically falls back to Gemini AI analysis if the Stockfish server is unreachable, so it always works either way.

---

### Step 7 — Run the app

```bash
cd chessdiary
flutter pub get
flutter run
```

Connect your Android phone via USB with USB Debugging enabled, or use an Android emulator.

---

## Project Structure

```
lib/
├── main.dart                  # App entry point
├── models/
│   └── game_model.dart        # ChessGame + MoveAnalysis data models
├── services/
│   ├── gemini_service.dart    # Gemini AI — parsing + analysis + coaching
│   ├── auth_service.dart      # Firebase Auth
│   └── game_service.dart      # Firestore CRUD + stats
├── screens/
│   ├── home_screen.dart       # Dashboard with recent games
│   ├── library_screen.dart    # Full game library with filters
│   ├── add_game_screen.dart   # Upload + AI parse flow (core feature)
│   ├── game_detail_screen.dart# Game overview + analysis tab
│   ├── progress_screen.dart   # Stats + AI coach insight
│   ├── login_screen.dart      # Login
│   └── signup_screen.dart     # Sign up
├── widgets/
│   └── game_card.dart         # Reusable game list card
└── utils/
    └── theme.dart             # Dark chess-themed UI
```

---

## How to Add a Game (User Flow)

1. Tap **+ Add Game**
2. Choose input method:
   - 📸 **Photo** — take photo of paper scoresheet
   - 📄 **PDF/Screenshot** — upload from online platform
   - ⌨️ **Paste** — paste PGN or move list
3. Fill in source (paper/chess.com/lichess), your colour, date
4. Tap **Parse with AI** → Gemini reads all the moves
5. Review the parsed data (player names, moves, result, opening)
6. Tap **Save to Library**
7. Open any game → **Analysis tab** → **Analyse with AI** for move-by-move feedback

---

## Known Limitations
- Gemini free tier: 1,500 parses/day (more than enough for personal use)
- Handwritten scoresheets with very messy writing may have lower parse confidence
- Game analysis is AI-based (not a chess engine) — for engine-level accuracy, a future version can integrate Stockfish

---

## Future Ideas
- Stockfish integration for precise centipawn analysis
- Opening explorer and statistics
- Share games with friends
- Export games as PGN
- iOS support (Flutter already supports it — just needs iOS Firebase setup)
