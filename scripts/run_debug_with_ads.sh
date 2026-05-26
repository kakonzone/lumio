#!/usr/bin/env bash
# Run Lumio with ads enabled in debug/profile (requires monetization defines).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

: "${CAP_BASE_URL:?Set CAP_BASE_URL (see docs/SECRETS.md)}"
: "${LEVELPLAY_APP_KEY:?Set LEVELPLAY_APP_KEY}"

DART_DEFINES=(
  "--dart-define=ADS_ENABLED=true"
  "--dart-define=LEVELPLAY_APP_KEY=${LEVELPLAY_APP_KEY}"
  "--dart-define=CAP_BASE_URL=${CAP_BASE_URL}"
)

optional() {
  local key="$1"
  local val="${!key:-}"
  if [[ -n "$val" ]]; then
    DART_DEFINES+=("--dart-define=${key}=${val}")
  fi
}

for key in \
  LEVELPLAY_INTERSTITIAL_AD_UNIT \
  LEVELPLAY_REWARDED_AD_UNIT \
  LEVELPLAY_BANNER_AD_UNIT \
  CAP_HMAC_KEY \
  ADSTERRA_DIRECT_LINK \
  ADSTERRA_POPUNDER_SCRIPT_URL \
  ADSTERRA_POPUNDER_BASE_URL; do
  optional "$key"
done

echo "==> flutter run (ADS_ENABLED=true)"
exec flutter run "${DART_DEFINES[@]}" "$@"
