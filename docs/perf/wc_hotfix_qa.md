# WC player hotfix — manual QA

**Branch:** `hotfix/player-perf-wc`  
**Build:** `app-arm64-v8a-release.apk` (release, arm64)  
**Device class:** Redmi 9 / Realme C-series / 2–3 GB RAM

| Test | Pass criteria | Result |
|------|---------------|--------|
| Cold launch → first stream | Loads at 540p on mobile | ☐ |
| 30 min continuous playback | Device warm, not hot to touch | ☐ |
| Battery drain over 1 hour | < 15% on Snapdragon 6xx / Helio G85 | ☐ |
| Switch streams 10 times | No probe spam in logs during playback | ☐ |
| Manual select 1080p on wifi | Respected, persists across restart | ☐ |
| Manual select 1080p on cellular auto-mode | Clamped to 720p | ☐ |
| PiP still works | Same as before | ☐ |
| Failover still works | Same as before | ☐ |
| Casting still works | Same as before | ☐ |

## Log patterns (release + `adb logcat`)

- During playback (60s): **no** `[probe]` / `[prewarm]` execute lines (skip lines OK).
- Pause 6s: one probe + one prewarm allowed.
- Resume within 3s of pause: skip or no execute.

## Automated verification (agent)

- `flutter test test/core/player/quality_config_test.dart` — 6 tests
- `flutter test test/features/player/idle_work_test.dart` — 4 tests
- `hwdec auto-safe` only in non-Android branch of `_configureMpvOnce`
- `vf` filter apply guarded with `!Platform.isAndroid` in `_applyMpvHeightCap`
