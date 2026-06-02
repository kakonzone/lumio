#!/usr/bin/env bash
# One release APK (universal) — same secrets.json as ./scripts/flutter_run_with_ads.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export BUILD_APK_MODE="${BUILD_APK_MODE:-fat}"
exec "$ROOT/tool/build_release_apk.sh" "$@"
