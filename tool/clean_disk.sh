#!/usr/bin/env bash
# PC disk: প্রজেক্ট build cache মুছে ~2–3 GB ফাঁকা
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

flutter clean
rm -rf build/ .dart_tool/ android/.gradle/ android/app/build/ 2>/dev/null || true

echo "Done. Project build artifacts removed."
