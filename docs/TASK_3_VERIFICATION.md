# TASK 3 — Secrets out of source — verification

## Automated

```bash
grep -rE 'YOUR_APP_KEY|adsterra\.com/zones' lib/ || echo "PASS"
flutter test test/config/ad_config_secrets_test.dart
flutter analyze lib/config/ad_config.dart lib/services/ironsource_service.dart
```

## Release build without env (must fail loudly)

```bash
bash scripts/build_release_apk.sh
# Expected: ERROR: LEVELPLAY_APP_KEY is not set
```

## Release build with env (must succeed)

```bash
# source .env from .env.example template
./scripts/build_release_apk.sh
```

## Device — no defines / empty keys

Install a debug or release APK built **without** monetization defines.

Expected logcat (app must not crash):

```
[AdManager.init] monetization config incomplete
[LevelPlay] init skipped — LEVELPLAY_APP_KEY empty
```

## Device — with defines

```
[LevelPlay] init success
```
