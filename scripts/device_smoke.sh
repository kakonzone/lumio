#!/usr/bin/env bash
# Wait for app ad-config marker, clear logcat, capture 60s of post-launch ad logs.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v adb >/dev/null 2>&1; then
  echo "ERROR: adb not found on PATH"
  exit 1
fi

if ! adb devices 2>/dev/null | grep -qE 'device$'; then
  echo "ERROR: no adb device connected (run: adb devices)"
  exit 1
fi

if [[ ! -f "${ROOT}/secrets.json" ]]; then
  echo "ERROR: secrets.json missing. Copy from secrets.json.template and fill values."
  exit 1
fi

LOG_DIR="${ROOT}/logs"
mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_DIR}/device_smoke_${STAMP}.log"
GREP_PATTERN='\[AdConfig\]|\[LevelPlay\]|\[RemoteConfig\]|\[Adsterra\]|\[ServerCap\]|\[AdManager\]|\[AdConsent\]|\[waterfall_step\]|LevelPlaySDK'

echo "==> Starting flutter run (background; cold build may take 60-120s)"
./scripts/flutter_run_with_ads.sh &
RUN_PID=$!

cleanup() {
  if kill -0 "$RUN_PID" 2>/dev/null; then
    kill "$RUN_PID" 2>/dev/null || true
    wait "$RUN_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

echo "==> Polling logcat every 3s for LEVELPLAY_APP_KEY=<set> (max 180s)"
READY=0
for _ in $(seq 1 60); do
  if adb logcat -d 2>/dev/null | grep -q 'LEVELPLAY_APP_KEY=<set>'; then
    READY=1
    break
  fi
  sleep 3
done

if [[ "$READY" != "1" ]]; then
  echo "[smoke] WARN: app-ready marker not seen in 180s"
else
  echo "==> App ready — clearing logcat for fresh 60s capture"
  adb logcat -c
  echo ""
  echo ">>> Tap HOME + 3 CHANNELS on the device now (60s window) <<<"
  echo ""
fi

sleep 60

echo "==> Saving filtered logcat to ${LOG_FILE}"
adb logcat -d | grep -E "$GREP_PATTERN" > "$LOG_FILE" || true

LINES=$(wc -l < "$LOG_FILE" | tr -d ' ')
echo "Log saved: ${LOG_FILE} (${LINES} lines)"

if [[ "$LINES" -lt 1 ]]; then
  echo "[smoke] FAIL: empty log"
  exit 1
fi

echo "Review for:"
echo "  - [AdConsent] stored consent applied to LevelPlay (granted)"
echo "  - [LevelPlay] setDynamicUserId before init"
echo "  - LevelPlaySDK ... LevelPlay=true"
echo "  - [LevelPlay] init success"
echo "  - [LevelPlay] banner loaded / interstitial loaded"
echo "  - [waterfall_step] ... levelplay ... fill"
