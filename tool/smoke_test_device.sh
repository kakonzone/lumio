#!/usr/bin/env bash
# Quick adb smoke helpers for World Cup release QA.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APK="${1:-$ROOT/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk}"

if [[ ! -f "$APK" ]]; then
  echo "APK not found: $APK" >&2
  echo "Run: ./tool/build_release_apk.sh" >&2
  exit 1
fi

echo "==> Installing $APK"
adb install -r "$APK"

echo "==> Launching app"
adb shell monkey -p com.kakonzone.lumio -c android.intent.category.LAUNCHER 1

echo "==> Deep link: Facebook World Cup campaign"
adb shell am start -a android.intent.action.VIEW \
  -d "lumio://open?source=facebook&campaign=wc2026&tab=sports"

echo "==> Tail logcat (Ctrl+C to stop) — look for [Lumio] [Splash] [AppOpenPromo]"
adb logcat -c
adb logcat | grep -E --line-buffered '\[Lumio\]|\[Splash\]|\[AppOpenPromo\]|\[ServerCap\]|flutter|Attribution|DeepLink'
