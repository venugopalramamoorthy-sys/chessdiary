"""
Deep check for chessdiary -- the slow, thorough companion to healthcheck.py.

Runs weekly (Task Scheduler, see run_deep.ps1) and after every deploy
(deploy.sh), against the live site:
  1. Browser tests: the Playwright suite in e2e/ (landing page, sign-in,
     sign-out; desktop + mobile), with one retry for flaky network.
  2. Pages: e2e/deep/sweep.js -- every sitemap page at phone width (loads,
     GA tag, no script errors, no sideways scroll) + internal links.
  3. Security: e2e/deep/security.js -- Firestore isolation, the backend's
     auth gate and size limits, and the public report rules end to end.

Sends one summary to ChessDiary's Telegram alert bot. Exit code 1 on any
failure. Needs e2e/node_modules (npm ci in e2e/), the repo-root .env.test
(test account) and healthcheck/secrets.json (Telegram).

Usage: python deep_check.py [--reason weekly|deploy] [--no-telegram]
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
E2E = HERE.parent / "e2e"
SITE = "https://chessdiary.app"


def run(cmd: str, timeout: int = 900) -> tuple[int, str]:
    # BASE_URL points Playwright at the live site (it then reuses it instead
    # of starting the local emulator). Don't set CI: that disables the reuse.
    env = {k: v for k, v in os.environ.items() if k != "CI"}
    env["BASE_URL"] = SITE
    try:
        p = subprocess.run(cmd, cwd=E2E, shell=True, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", env=env, timeout=timeout)
        return p.returncode, p.stdout + p.stderr
    except subprocess.TimeoutExpired:
        return 1, f"FAIL timed out after {timeout}s"


def browser_tests() -> tuple[int, int, list[str]]:
    code, out = run("npx playwright test --reporter=line --retries=1", timeout=1200)
    passed = sum(int(n) for n in re.findall(r"(\d+) passed", out))
    flaky = sum(int(n) for n in re.findall(r"(\d+) flaky", out))
    failed = sum(int(n) for n in re.findall(r"(\d+) failed", out))
    names = [re.sub(r"\s+", " ", m).strip() for m in re.findall(r"^\s+\d+\) (\[.*?\] › .*)$", out, re.M)]
    if code != 0 and failed == 0:  # crashed before reporting
        failed, names = 1, [out.strip().splitlines()[-1][:150] if out.strip() else "playwright did not run"]
    # A test that passed on retry counts as passed, but is worth a mention.
    notes = [f"{flaky} flaky (passed on retry)"] if flaky else []
    return passed + flaky, failed, names[:6] + notes


def node_check(script: str) -> tuple[int, int, list[str]]:
    code, out = run(f"node {script}")
    m = re.search(r"^SUMMARY (\d+) (\d+)", out, re.M)
    fails = [l[5:].strip()[:150] for l in out.splitlines() if l.startswith("FAIL ")]
    if not m:
        return 0, 1, fails or [out.strip().splitlines()[-1][:150] if out.strip() else f"{script} did not run"]
    return int(m.group(1)), int(m.group(2)), fails[:6]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--reason", default="weekly", choices=["weekly", "deploy", "manual"])
    ap.add_argument("--no-telegram", action="store_true")
    args = ap.parse_args()

    if not (E2E / "node_modules").exists():
        print("e2e/node_modules missing -- run `npm ci` in e2e/ first")
        return 1

    parts = {}
    print("Browser tests...");  parts["Browser tests"] = browser_tests()
    print("Page sweep...");     parts["Pages"] = node_check("deep/sweep.js")
    print("Security...");       parts["Security"] = node_check("deep/security.js")

    total_p = sum(p for p, _, _ in parts.values())
    total_f = sum(f for _, f, _ in parts.values())
    label = {"weekly": "weekly", "deploy": "after deploy", "manual": "manual run"}[args.reason]
    head = (f"ChessDiary deep check ({label}): all {total_p} passed" if not total_f
            else f"ChessDiary deep check ({label}): {total_f} FAILED, {total_p} passed")
    lines = [head]
    for name, (p, f, details) in parts.items():
        lines.append(f"{name}: {p}/{p + f}" + (" FAIL" if f else " OK"))
        lines += [f"  - {d}" for d in details if f or "flaky" in d]
    report = "\n".join(lines)
    print("\n" + report + "\n")

    if not args.no_telegram:
        sys.path.insert(0, str(HERE))
        from healthcheck import send_telegram  # reuses the daily check's bot + secrets
        print("Telegram delivery:", "OK" if send_telegram(report) else "FAILED")
    return 1 if total_f else 0


if __name__ == "__main__":
    sys.exit(main())
