#!/usr/bin/env bash
# Firebase Console gate — run before release device testing.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok() { echo -e "${GREEN}OK${NC} $*"; }
warn() { echo -e "${YELLOW}WARN${NC} $*"; }
fail() { echo -e "${RED}FAIL${NC} $*"; }

GS_JSON="android/app/google-services.json"
APP_ID=""
if [[ -f "$GS_JSON" ]]; then
  ok "google-services.json exists"
  APP_ID=$(python3 -c "import json; print(json.load(open('$GS_JSON'))['client'][0]['client_info']['android_client_info']['package_name'])" 2>/dev/null || true)
  echo "  package_name from JSON: ${APP_ID:-<parse failed>}"
else
  fail "google-services.json missing at $GS_JSON"
fi

GRADLE_ID=$(grep -E 'applicationId\s*=' android/app/build.gradle.kts | head -1 | sed -E 's/.*"(.*)".*/\1/' || true)
echo "  applicationId in build.gradle.kts: ${GRADLE_ID:-<not found>}"
if [[ -n "$APP_ID" && -n "$GRADLE_ID" && "$APP_ID" != "$GRADLE_ID" ]]; then
  fail "package_name mismatch: JSON=$APP_ID gradle=$GRADLE_ID"
elif [[ -n "$APP_ID" && -n "$GRADLE_ID" ]]; then
  ok "package_name matches"
fi

echo ""
echo "=== Debug keystore SHA-1 (paste in Firebase Console) ==="
if command -v keytool >/dev/null 2>&1; then
  keytool -list -v -keystore "${HOME}/.android/debug.keystore" -alias androiddebugkey \
    -storepass android -keypass android 2>/dev/null | grep -E 'SHA1:|SHA-1:' || warn "debug keystore not found"
else
  warn "keytool not in PATH"
fi

if [[ -f android/key.properties ]]; then
  STORE=$(grep '^storeFile=' android/key.properties | cut -d= -f2- | tr -d ' ')
  if [[ -n "$STORE" ]]; then
    STORE_PATH="android/${STORE#app/}"
    [[ -f "android/$STORE" ]] && STORE_PATH="android/$STORE"
    [[ -f "$STORE" ]] && STORE_PATH="$STORE"
    echo ""
    echo "=== Release keystore SHA-1 ==="
    if [[ -f "$STORE_PATH" ]]; then
      keytool -list -v -keystore "$STORE_PATH" 2>/dev/null | grep -E 'SHA1:|SHA-1:' || warn "could not read release keystore"
    fi
  fi
fi

echo ""
echo "=== Remote Config keys (publish in Console) ==="
cat <<'RC'
| Parameter | Type | In-app default if missing |
|-----------|------|---------------------------|
| ads_enabled | Boolean | true |
| levelplay_enabled | Boolean | true |
| adsterra_enabled | Boolean | true |
| vpn_locale_strictness | String | loose (off|loose|strict) |
| popunder_session_cap | Number | 2 |
| aggressive_mode | Boolean | false |
RC

echo ""
echo "=== Human checklist ==="
echo "  [ ] Add debug SHA-1 to Firebase → Project settings → Android app"
echo "  [ ] Add release SHA-1/SHA-256 before Play upload"
echo "  [ ] Create Remote Config parameters above and Publish"
echo "  [ ] Enable Crashlytics in Firebase Console"
echo "  [ ] Run: flutter test test/services/firebase_bootstrap_test.dart"
