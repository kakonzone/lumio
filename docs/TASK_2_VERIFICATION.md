# TASK 2 — ADS_ENABLED dart-define — verification

## Automated

```bash
flutter test test/config/ad_config_ads_enabled_test.dart test/services/ad_safety_migration_test.dart
flutter analyze lib/config/ad_config.dart lib/services/ad_safety_service.dart lib/services/ironsource_service.dart lib/ads/
```

## Device — ads OFF (default)

```bash
adb logcat -c
flutter run
adb logcat -d | grep -E 'AdSafety|LevelPlay'
```

Expected:

```
[AdSafety] ads blocked in non-release build — pass --dart-define=ADS_ENABLED=true
[LevelPlay] init skipped — pass --dart-define=ADS_ENABLED=true
```

No banner/interstitial fill.

## Device — ads ON

```bash
./scripts/run_debug_with_ads.sh
# or flutter run --dart-define=ADS_ENABLED=true ... (see docs/AD_TESTING.md)
```

Expected (with keys + consent granted):

```
[AdSafety] ADS_ENABLED=true — ads enabled in non-release build
[LevelPlay] init success
```

## Grep guard

```bash
grep -rn 'kDebugMode' lib/services/ironsource_service.dart lib/services/ad_safety_service.dart lib/services/ad_consent_service.dart lib/ads/
```

Must return **no matches** (except comment in `ad_log.dart`).
