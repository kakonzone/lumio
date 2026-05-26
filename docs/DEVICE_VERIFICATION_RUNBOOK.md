# Device verification runbook — ads layer

## Logcat filters

```bash
adb logcat -c
# run app, exercise flows, then:
adb logcat -d | grep -E 'Lumio|RemoteConfig|AdSafety|LevelPlay|AdDebug|Cap\]|waterfall_step|AdAnalytics|Adsterra'
```

## Expected lines by feature

| Feature | Log pattern |
|---------|-------------|
| Firebase | `[Lumio] Firebase init OK` |
| Remote Config | `[RemoteConfig] fetchAndActivate activated=true` |
| Ads blocked (debug) | `[AdSafety] ads blocked` / `[LevelPlay] init skipped — pass --dart-define=ADS_ENABLED=true` |
| Ads enabled (debug) | `[AdSafety] ADS_ENABLED=true` |
| LevelPlay init | `[LevelPlay] init success` |
| Interstitial shown | `[Cap] shown placement=interstitial` |
| Interstitial timeout | `[Interstitial] timeout — cap not recorded` |
| Popunder mount | `[AdManager] popunder mounted` |
| Popunder blocked | `popunder blocked — host will not mount` |
| Waterfall | `[waterfall_step] step=primary network=levelplay` |
| Aggressive RC | `[AdManager] init OK aggressive_mode=true` |

## Script

```bash
./scripts/capture_logcat.sh
```
