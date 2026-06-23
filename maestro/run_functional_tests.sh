#!/usr/bin/env bash
# ChessDiary Functional Test Pack
# Usage: bash maestro/run_functional_tests.sh
# Prerequisite: Maestro installed and in PATH, device/emulator connected

set -e

DEVICE_ID="${MAESTRO_DEVICE_ID:-}"  # optional: set to specific device ID
DEVICE_FLAG=""
if [ -n "$DEVICE_ID" ]; then
  DEVICE_FLAG="--device $DEVICE_ID"
fi

# Push test PGN to device storage (needed for flow_add_game_pgn_file.yaml)
echo "📁 Pushing test assets to device..."
adb ${DEVICE_ID:+-s $DEVICE_ID} push maestro/test_assets/test_game.pgn /sdcard/Download/test_game.pgn

echo ""
echo "🎭 ChessDiary Functional Test Pack"
echo "==================================="
echo ""

PASS=0
FAIL=0
FAILED_FLOWS=()

run_flow() {
  local flow=$1
  local name=$(basename "$flow" .yaml)
  printf "%-40s " "$name"
  if maestro $DEVICE_FLAG test "$flow" --no-ansi 2>&1 | tail -1 | grep -q "COMPLETED"; then
    echo "✅ PASS"
    PASS=$((PASS + 1))
  else
    echo "❌ FAIL"
    FAIL=$((FAIL + 1))
    FAILED_FLOWS+=("$name")
  fi
}

# Run all flows
# NOTE: flow_login must succeed first — subsequent flows reuse its session via _ensure_home.yaml
# flow_google_signin runs last because it clears app state
run_flow maestro/flows/flow_signup.yaml
run_flow maestro/flows/flow_login.yaml
run_flow maestro/flows/flow_add_game_paste.yaml
run_flow maestro/flows/flow_add_game_pgn_file.yaml
run_flow maestro/flows/flow_add_game_cancel.yaml
run_flow maestro/flows/flow_library_search.yaml
run_flow maestro/flows/flow_library_filter.yaml
run_flow maestro/flows/flow_game_overview.yaml
run_flow maestro/flows/flow_game_replay.yaml
run_flow maestro/flows/flow_game_analysis.yaml
run_flow maestro/flows/flow_progress_load.yaml
run_flow maestro/flows/flow_progress_empty_state.yaml
run_flow maestro/flows/flow_nav_stress.yaml
run_flow maestro/flows/flow_library_delete.yaml
run_flow maestro/flows/flow_google_signin.yaml

echo ""
echo "==================================="
echo "Results: $PASS passed, $FAIL failed"
if [ ${#FAILED_FLOWS[@]} -gt 0 ]; then
  echo ""
  echo "Failed flows:"
  for f in "${FAILED_FLOWS[@]}"; do
    echo "  ❌ $f"
  done
  echo ""
  echo "Re-run a single flow with:"
  echo "  maestro test maestro/flows/<flow_name>.yaml"
fi
echo ""
[ $FAIL -eq 0 ] && exit 0 || exit 1
