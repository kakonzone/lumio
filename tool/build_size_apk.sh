#!/usr/bin/env bash
# Same as build_release_apk.sh default (split 32-bit + 64-bit APKs, secrets.json).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export BUILD_APK_MODE="${BUILD_APK_MODE:-split}"
GRADLE_EXTRA=()
KEY_PROPS="$ROOT/android/key.properties"
if [[ ! -f "$KEY_PROPS" ]] || ! grep -qE '^storeFile=' "$KEY_PROPS" 2>/dev/null; then
  GRADLE_EXTRA=(--android-project-arg=LUMIO_LOCAL_SIZE_CHECK=true)
fi
exec "$ROOT/tool/build_release_apk.sh" "${GRADLE_EXTRA[@]}" "$@"
