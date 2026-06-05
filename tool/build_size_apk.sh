#!/usr/bin/env bash
# Size-focused release build: arm64-only single APK (~20–35 MB target).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export BUILD_APK_MODE="${BUILD_APK_MODE:-arm64}"
GRADLE_EXTRA=()
KEY_PROPS="$ROOT/android/key.properties"
if [[ ! -f "$KEY_PROPS" ]] || ! grep -qE '^storeFile=' "$KEY_PROPS" 2>/dev/null; then
  GRADLE_EXTRA=(--android-project-arg=LUMIO_LOCAL_SIZE_CHECK=true)
fi
exec "$ROOT/tool/build_release_apk.sh" \
  --dart-define=CAP_LOCAL_ONLY_MODE=true \
  --dart-define=LUMIO_SIDELOAD_DEV=true \
  "${GRADLE_EXTRA[@]}" "$@"
