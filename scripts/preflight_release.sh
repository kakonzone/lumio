#!/usr/bin/env bash
# Release preflight — Phase 7 + Phase 8 gates.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Lumio release preflight ==="
bash scripts/firebase_precheck.sh
echo ""
echo "=== Secret scan (lib/) ==="
flutter test test/security/no_secrets_in_lib_test.dart
echo ""
echo "=== Analyze ==="
flutter analyze --fatal-warnings
echo ""
echo "=== Tests ==="
flutter test
echo ""
echo "Preflight complete. Build with: ./scripts/build_release_apk.sh"
