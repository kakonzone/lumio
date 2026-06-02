#!/usr/bin/env bash
# LUMIO সিকিউর রিলিজ বিল্ড — অবফাসকেশন + স্প্লিট ABI
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SYMBOLS_DIR="${SYMBOLS_DIR:-$ROOT/debug-symbols}"
BUILD_NUMBER="${BUILD_NUMBER:-}"

echo "==> flutter pub get"
flutter pub get

if [[ -f tool/secrets_input.json ]]; then
  echo "==> Encrypting strings"
  dart run tool/encrypt_strings.dart --input tool/secrets_input.json
fi

EXTRA_BUILD_ARGS=()
if [[ -n "$BUILD_NUMBER" ]]; then
  EXTRA_BUILD_ARGS+=(--build-number="$BUILD_NUMBER")
fi

echo "==> Building release APK (split ABI, obfuscated)"
flutter build apk \
  --release \
  --obfuscate \
  --split-debug-info="$SYMBOLS_DIR" \
  --split-per-abi \
  --target-platform=android-arm64 \
  --tree-shake-icons \
  "${EXTRA_BUILD_ARGS[@]}"

echo ""
echo "Done. Install ONE of these (not a fat/universal APK):"
echo "  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk   (~90-110 MB typical)"
echo "  build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk"
echo "Symbols (রাখুন, ক্র্যাশ ডিকোডের জন্য): $SYMBOLS_DIR"
