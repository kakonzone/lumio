#!/usr/bin/env bash
# Score LevelPlay / consent lines from a log file or live adb logcat -d.
set -euo pipefail

if [[ -n "${1:-}" ]]; then
  LOG="$1"
else
  LOG=$(mktemp)
  trap 'rm -f "$LOG"' EXIT
  adb logcat -d 2>/dev/null | grep -iE 'flutter|LevelPlaySDK' > "$LOG" || true
fi

FAIL=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; FAIL=1; }
warn() { echo "WARN  $1"; }

grep -q 'LEVELPLAY_APP_KEY=<set>' "$LOG" && pass 'LEVELPLAY_APP_KEY=<set>' || fail 'LEVELPLAY_APP_KEY=<set> (use ./scripts/flutter_run_with_ads.sh)'
grep -q 'stored consent applied to LevelPlay (granted)' "$LOG" && pass 'stored consent (granted)' || fail 'stored consent applied'
grep -q 'LevelPlay=true' "$LOG" && pass 'native LevelPlay=true' || warn 'native LevelPlay=true not seen'
grep -q 'ads blocked in non-release' "$LOG" && fail 'ADS_ENABLED missing (debug gate)' || pass 'no debug ads-blocked line'
grep -q 'monetization config incomplete' "$LOG" && fail 'monetization config incomplete' || pass 'no monetization incomplete error'
grep -q '\[LevelPlay\] init success' "$LOG" && pass 'LevelPlay init success' || warn 'LevelPlay init success (needs defines + consent gate)'
grep -qE 'banner loaded|interstitial loaded' "$LOG" && pass 'LP ad loaded' || warn 'banner/interstitial loaded'
grep -q 'waterfall_step.*levelplay.*fill' "$LOG" && pass 'waterfall levelplay fill' || warn 'waterfall levelplay fill'

exit "$FAIL"
