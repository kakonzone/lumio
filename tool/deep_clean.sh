#!/usr/bin/env bash
# When `flutter clean` fails with "Directory not empty" on build/, use this.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter clean 2>/dev/null || true
rm -rf build .dart_tool
flutter pub get
echo "Done. Run: flutter run --release or ./tool/build_size_apk.sh"
