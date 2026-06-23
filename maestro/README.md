# ChessDiary Functional Test Pack

End-to-end UI tests using Maestro. Tests run against the real app on a device.

## Setup (one-time)

### 1. Install Maestro
Download from https://github.com/mobile-dev-inc/maestro/releases/latest
Extract and add `bin/` to PATH. Verify with: `maestro --version`

### 2. Create the test Firebase account
In Firebase Console → Authentication → Add user:
- Email: `testuser@chessdiary.test`
- Password: `TestPass123!`

Use this account for all functional tests — never your real account.

### 3. Push test assets to device
```bash
adb push maestro/test_assets/test_game.pgn /sdcard/Download/test_game.pgn
```

## Running tests

### Run everything (recommended after any UI change)
```bash
bash maestro/run_functional_tests.sh
```

### Run a single flow
```bash
maestro test maestro/flows/flow_login.yaml
```

### Run with verbose output
```bash
maestro test maestro/flows/flow_login.yaml --debug-output
```

## Flow inventory

| Flow | What it tests |
|---|---|
| `flow_signup` | Sign up screen fields and navigation |
| `flow_login` | Login with email/password → Home |
| `flow_google_signin` | Google picker appears (stops before OAuth) |
| `flow_add_game_paste` | Paste PGN → Parse → Save → Library |
| `flow_add_game_pgn_file` | Upload .pgn → native parse (no AI spinner) |
| `flow_add_game_cancel` | Back out midway → no crash, no partial save |
| `flow_library_search` | Search by opponent name → filtered results |
| `flow_library_filter` | Source + result + time-control filter chips |
| `flow_library_delete` | Open game → delete → confirm removal |
| `flow_game_overview` | Overview tab shows result/date/metadata |
| `flow_game_replay` | Replay tab step forward/back/jump |
| `flow_game_analysis` | Trigger analysis → motif/phase badges appear |
| `flow_progress_load` | Progress screen renders all cards without crash |
| `flow_progress_empty_state` | Empty states on fresh account (no crash) |
| `flow_nav_stress` | Rapid tab switching × 3 cycles, no crash |

## When to run

| Situation | Run |
|---|---|
| After any screen/navigation change | `bash maestro/run_functional_tests.sh` |
| After a logic-only change | `flutter test test/` (unit tests) is enough |
| Before manual testing session | Full pack to catch obvious breakage fast |
| Before Play Store upload | Full pack + manual checklist |
