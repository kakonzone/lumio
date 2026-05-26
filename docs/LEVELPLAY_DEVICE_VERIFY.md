# LevelPlay device verification (post P7-006 / P7-007)

Run **after** pulling latest code. Force-stop Lumio on device first.

## Quick path

```bash
adb logcat -c
./scripts/flutter_run_with_ads.sh
# Wait for app on screen — tap HOME + 3 channels
./scripts/verify_levelplay_logs.sh
```

## Automated smoke capture

```bash
./scripts/device_smoke.sh
./scripts/verify_levelplay_logs.sh logs/device_smoke_*.log
```

## Pass criteria

| # | Log evidence |
|---|----------------|
| 1 | `[AdConfig] … LEVELPLAY_APP_KEY=<set>` |
| 2 | `[AdConsent] stored consent applied to LevelPlay (granted)` |
| 3 | `[LevelPlay] setDynamicUserId before init` |
| 4 | Native `LevelPlaySDK` … `LevelPlay=true` (when granted) |
| 5 | `[LevelPlay] init success` |
| 6 | `[LevelPlay] banner loaded` and/or `interstitial loaded` |
| 7 | `[waterfall_step] … levelplay … fill` (optional; dashboard may block) |

## If only Adsterra shows

- Code OK if steps 1–5 pass but step 6–7 fail → IronSource dashboard: app **Live**, test mode **off**, mediation networks enabled.
