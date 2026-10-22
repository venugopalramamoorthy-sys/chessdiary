"""
Daily deep health check for chessdiary -- runs locally (Windows Task
Scheduler, see run_daily.ps1) instead of as a Claude cloud routine.

Background: the equivalent cloud routine (claude.ai routines, trigger
trig_01EmshszbBSL7PeXjrSV9Vqr) is blocked by its sandbox's network
egress policy, which only allows *.googleapis.com and a handful of
package registries -- chessdiary.app, the Firebase web.app domain, the
Render backend, and the trading-terminal Telegram relay are all
rejected. That policy lives in claude.ai's cloud-environment settings
(a pure click-through UI with no API/URL, confirmed via Anthropic's own
docs), not something fixable from code. Running the exact same checks
from this machine's own unrestricted network sidesteps the problem
entirely. The cloud routine is left in place but disabled -- see the
note at the bottom of this file.

Tests, in order:
  1. Website (chessdiary.app) + Flutter app shell (chessdiary.app/app)
     + the underlying Firebase Hosting domain.
  2. Stockfish backend /health (Render free tier -- retries on cold start).
  3. Auth-gate regression check: /analyze and /gemini must both still
     reject unauthenticated requests (confirms the Oct 2026 security
     fix hasn't been rolled back).
  4. Sign in as the dedicated healthcheck-bot@chessdiary-monitor.internal
     account to get a real Firebase ID token.
  5. Functional /analyze test -- a real PGN through the Stockfish engine,
     checking the response shape and move-quality values, not just the
     status code.
  6. Functional /gemini test -- a real Gemini API call, distinguishing
     "quota exhausted" (needs billing attention) from "model not found"
     (the pinned model name in gemini_service.dart needs updating) from
     a clean pass.
  7. Firestore round-trip under the real per-user security rule
     (write -> read back -> delete the test doc).
  8. Compose a plain-text report and send it via trading-terminal's
     existing Telegram relay (chessdiary has no channel of its own).
"""

from __future__ import annotations

import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import requests

# Credentials live in secrets.json next to this script (gitignored --
# this repo is public). Keys: WEB_API_KEY, HEALTHCHECK_EMAIL,
# HEALTHCHECK_PASSWORD, AUTOMATION_SECRET, and optionally
# TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID for ChessDiary's own alert bot.
_SECRETS_PATH = Path(__file__).resolve().parent / "secrets.json"
_SECRETS = json.loads(_SECRETS_PATH.read_text(encoding="utf-8"))

WEB_API_KEY = _SECRETS["WEB_API_KEY"]
PROJECT_ID = "chessdiary-7f1e3"
HEALTHCHECK_EMAIL = _SECRETS["HEALTHCHECK_EMAIL"]
HEALTHCHECK_PASSWORD = _SECRETS["HEALTHCHECK_PASSWORD"]

WEBSITE_URL = "https://chessdiary.app/"
APP_SHELL_URL = "https://chessdiary.app/app"
WEBAPP_URL = "https://chessdiary-7f1e3.web.app/"
BACKEND_URL = "https://chessdiary-stockfish.onrender.com"

AUTOMATION_SECRET = _SECRETS["AUTOMATION_SECRET"]
NOTIFY_URL = "https://43-205-148-181.sslip.io/automation/notify"

# ChessDiary's own Telegram bot. When both are set, reports go straight to
# Telegram instead of through the trading-terminal relay above.
TELEGRAM_BOT_TOKEN = _SECRETS.get("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_CHAT_ID = _SECRETS.get("TELEGRAM_CHAT_ID", "")

TEST_PGN = "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6"
VALID_QUALITIES = {"best", "good", "inaccuracy", "mistake", "blunder"}


def check_website() -> str:
    try:
        r = requests.get(WEBSITE_URL, timeout=20)
        if r.status_code != 200:
            return f"FAIL (landing page HTTP {r.status_code})"
        if len(r.text) < 200 or "firebase" in r.text.lower()[:500] and "welcome" in r.text.lower()[:500]:
            return "FAIL (landing page looks blank or like a Firebase placeholder)"
    except Exception as e:
        return f"FAIL (landing page: {e})"

    try:
        r = requests.get(APP_SHELL_URL, timeout=20)
        if r.status_code != 200 or ("flutter" not in r.text.lower() and "<title" not in r.text.lower()):
            return f"FAIL (app shell HTTP {r.status_code}, no Flutter/title markers found)"
    except Exception as e:
        return f"FAIL (app shell: {e})"

    try:
        r = requests.get(WEBAPP_URL, timeout=20)
        if r.status_code != 200:
            return f"FAIL (web.app domain HTTP {r.status_code})"
    except Exception as e:
        return f"FAIL (web.app domain: {e})"

    return "OK"


def check_backend_health() -> tuple[str, bool]:
    """Returns (status_text, is_up). Retries for Render free-tier cold starts."""
    last_err = None
    for attempt in range(3):
        try:
            r = requests.get(f"{BACKEND_URL}/health", timeout=60)
            if r.status_code == 200 and r.json().get("status") == "ok":
                return "OK", True
            last_err = f"HTTP {r.status_code}: {r.text[:200]}"
        except Exception as e:
            last_err = str(e)
        if attempt < 2:
            time.sleep(15)
    return f"FAIL ({last_err})", False


def check_auth_gate() -> str:
    problems = []
    try:
        r = requests.post(f"{BACKEND_URL}/gemini", json={"contents": []}, timeout=30)
        if r.status_code != 401:
            problems.append(f"/gemini returned {r.status_code} without auth (expected 401) -- CRITICAL, auth gate may have regressed")
    except Exception as e:
        problems.append(f"/gemini check errored: {e}")

    try:
        r = requests.post(f"{BACKEND_URL}/analyze", json={"pgn": "1. e4 e5"}, timeout=30)
        if r.status_code != 401:
            problems.append(f"/analyze returned {r.status_code} without auth (expected 401) -- CRITICAL, auth gate may have regressed")
    except Exception as e:
        problems.append(f"/analyze check errored: {e}")

    return "OK" if not problems else "; ".join(problems)


def sign_in() -> tuple[str | None, str | None, str | None]:
    """Returns (id_token, uid, error)."""
    try:
        r = requests.post(
            f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={WEB_API_KEY}",
            json={"email": HEALTHCHECK_EMAIL, "password": HEALTHCHECK_PASSWORD, "returnSecureToken": True},
            timeout=20,
        )
        if r.status_code != 200:
            return None, None, f"HTTP {r.status_code}: {r.text[:200]}"
        data = r.json()
        return data["idToken"], data["localId"], None
    except Exception as e:
        return None, None, str(e)


def check_analyze(token: str) -> str:
    try:
        r = requests.post(
            f"{BACKEND_URL}/analyze",
            json={"pgn": TEST_PGN},
            headers={"Authorization": f"Bearer {token}"},
            timeout=60,
        )
        if r.status_code != 200:
            return f"FAIL (HTTP {r.status_code}: {r.text[:200]})"
        data = r.json()
        analysis = data.get("analysis", [])
        eval_curve = data.get("evalCurve", [])
        if not analysis or not eval_curve:
            return "FAIL (empty analysis or evalCurve -- Stockfish may not be returning real results)"
        bad_quality = [a for a in analysis if a.get("quality") not in VALID_QUALITIES]
        if bad_quality:
            return f"FAIL ({len(bad_quality)} entries with unexpected quality values)"
        return "OK"
    except Exception as e:
        return f"FAIL ({e})"


def check_gemini(token: str) -> str:
    try:
        r = requests.post(
            f"{BACKEND_URL}/gemini",
            json={
                "model": "gemini-2.5-flash",
                "contents": [{"parts": [{"text": "Reply with exactly the single word: pong"}]}],
            },
            headers={"Authorization": f"Bearer {token}"},
            timeout=60,
        )
        body_lower = r.text.lower()
        if r.status_code == 200:
            candidates = r.json().get("candidates", [])
            if candidates and "pong" in json.dumps(candidates).lower():
                return "OK"
            return "FAIL (200 but response didn't contain expected text -- check manually)"
        if r.status_code == 429 or "resource_exhausted" in body_lower or "quota" in body_lower:
            return "QUOTA EXHAUSTED -- Gemini free-tier limit hit, billing/top-up attention may be needed"
        if r.status_code == 404 or "not found" in body_lower or "not supported" in body_lower:
            return "MODEL ISSUE -- pinned model name in lib/services/gemini_service.dart may need updating (not a quota problem)"
        return f"FAIL (HTTP {r.status_code}: {r.text[:200]})"
    except Exception as e:
        return f"FAIL ({e})"


def check_firestore(token: str, uid: str) -> str:
    doc_path = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/users/{uid}/_healthcheck/ping"
    headers = {"Authorization": f"Bearer {token}"}
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    try:
        r = requests.patch(doc_path, headers=headers, json={"fields": {"checkedAt": {"timestampValue": now}}}, timeout=20)
        if r.status_code != 200:
            return f"FAIL (write HTTP {r.status_code}: {r.text[:200]})"

        r = requests.get(doc_path, headers=headers, timeout=20)
        if r.status_code != 200:
            return f"FAIL (readback HTTP {r.status_code}: {r.text[:200]})"
        got = r.json().get("fields", {}).get("checkedAt", {}).get("timestampValue")
        if got != now:
            return f"FAIL (timestamp mismatch: wrote {now}, read {got})"

        r = requests.delete(doc_path, headers=headers, timeout=20)
        if r.status_code != 200:
            return f"FAIL (cleanup delete HTTP {r.status_code} -- test doc may be left behind)"

        return "OK"
    except Exception as e:
        return f"FAIL ({e})"


def send_telegram(text: str) -> bool:
    if TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID:
        try:
            r = requests.post(
                f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage",
                json={"chat_id": TELEGRAM_CHAT_ID, "text": text},
                timeout=20,
            )
            return r.status_code == 200 and r.json().get("ok") is True
        except Exception:
            return False

    try:
        r = requests.post(
            NOTIFY_URL,
            headers={"X-Automation-Secret": AUTOMATION_SECRET, "Content-Type": "application/json"},
            json={"text": text},
            timeout=20,
        )
        return r.status_code == 200 and r.json().get("sent") is True
    except Exception:
        return False


def main() -> int:
    results = {}

    print("Checking website/hosting...")
    results["Website"] = check_website()

    print("Checking backend health...")
    backend_status, backend_up = check_backend_health()
    results["Backend"] = backend_status

    print("Checking auth gate regression...")
    results["Auth gate"] = check_auth_gate() if backend_up else "SKIPPED (backend down)"

    print("Signing in as healthcheck account...")
    token, uid, sign_in_err = sign_in()
    if sign_in_err:
        results["Stockfish analysis"] = f"SKIPPED (sign-in failed: {sign_in_err})"
        results["Gemini API"] = f"SKIPPED (sign-in failed: {sign_in_err})"
        results["Firestore"] = f"SKIPPED (sign-in failed: {sign_in_err})"
    else:
        print("Checking /analyze functional test...")
        results["Stockfish analysis"] = check_analyze(token) if backend_up else "SKIPPED (backend down)"

        print("Checking /gemini functional test...")
        results["Gemini API"] = check_gemini(token) if backend_up else "SKIPPED (backend down)"

        print("Checking Firestore round-trip...")
        results["Firestore"] = check_firestore(token, uid)

    lines = ["ChessDiary daily health check (local):"]
    for area, status in results.items():
        lines.append(f"{area}: {status}")
    report = "\n".join(lines)

    print()
    print(report)
    print()

    sent = send_telegram(report)
    print(f"Telegram delivery: {'OK' if sent else 'FAILED'}")

    any_failure = any("FAIL" in v or "CRITICAL" in v or "QUOTA" in v or "MODEL ISSUE" in v for v in results.values())
    return 1 if any_failure else 0


if __name__ == "__main__":
    sys.exit(main())
