#!/usr/bin/env bash
# Play Store AAB — Google serves smallest split per device (~35–50 MB download)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SYMBOLS_DIR="${SYMBOLS_DIR:-$ROOT/build/debug-info}"

flutter pub get

echo "==> App Bundle (arm ABIs, obfuscated)"
flutter build appbundle \
  --release \
  --target-platform=android-arm,android-arm64 \
  --obfuscate \
  --split-debug-info="$SYMBOLS_DIR" \
  --tree-shake-icons \
  "$@"

echo ""
ls -lh build/app/outputs/bundle/release/*.aab 2>/dev/null || true
