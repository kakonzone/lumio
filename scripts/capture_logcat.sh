#!/usr/bin/env bash
# Capture ads-related logcat to repo-adjacent file (gitignored pattern: device_test_*.log).
set -euo pipefail
OUT="device_test_$(date +%s).log"
adb logcat -d | grep -E 'flutter|Lumio|RemoteConfig|AdSafety|LevelPlay|AdDebug|Cap\]|waterfall_step|AdAnalytics|Adsterra|Interstitial' > "$OUT" || true
echo "Wrote $OUT ($(wc -l < "$OUT") lines)"
