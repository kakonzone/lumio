# Ad QA in debug/profile builds

Non-release builds **do not load ads by default**. Use compile-time flags — not `kDebugMode`.

## Enable ads locally

```bash
export LEVELPLAY_APP_KEY='your_key'
export CAP_BASE_URL='https://your-cap-host.example'
export CAP_HMAC_KEY='your_hmac_secret'
# Optional Adsterra zones — see docs/SECRETS.md

./scripts/run_debug_with_ads.sh
```

Or manually:

```bash
flutter run \
  --dart-define=ADS_ENABLED=true \
  --dart-define=LEVELPLAY_APP_KEY=... \
  --dart-define=CAP_BASE_URL=... \
  --dart-define=CAP_HMAC_KEY=...
```

## Safe default (no ads)

```bash
flutter run
```

Expect logcat:

```
[AdSafety] ads blocked in non-release build — pass --dart-define=ADS_ENABLED=true
[LevelPlay] init skipped — pass --dart-define=ADS_ENABLED=true
```

## Legacy flag

`--dart-define=ADS_TEST_MODE=true` still enables ads (alias). Prefer **`ADS_ENABLED`** for new scripts.

## Release builds

Release ignores `ADS_ENABLED` / `ADS_TEST_MODE` for gating — ads follow consent, Remote Config, and caps only.
