#!/usr/bin/env bash
# Debug run with monetization keys + ADS_ENABLED (required in non-release).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SECRETS="${ROOT}/secrets.json"
if [[ ! -f "$SECRETS" ]]; then
  echo "ERROR: secrets.json missing. Copy from secrets.json.template and fill values."
  exit 1
fi

echo "==> flutter run --dart-define-from-file=secrets.json"
echo "    Includes ADS_ENABLED, LevelPlay, Adsterra, TOFFEE_SUBSCRIBER_TOKEN, etc."
echo "    (full restart required after changing secrets — not hot reload)"
exec flutter run --dart-define-from-file=secrets.json "$@"
