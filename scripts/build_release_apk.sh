#!/usr/bin/env bash
# Wrapper — release APK build with required dart-defines (see docs/SECRETS.md).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT/tool/build_release_apk.sh" "$@"
