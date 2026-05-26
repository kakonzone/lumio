# Secrets migration — ad keys out of source

**Status (2026-05-25):** All monetization credentials read from `--dart-define` via `lib/config/ad_config.dart`. No production keys belong in git.

## If keys were ever committed

**MUST ROTATE** in each dashboard:

| Secret | Where to rotate |
|--------|-----------------|
| `LEVELPLAY_APP_KEY` | ironSource / LevelPlay → App settings |
| LevelPlay ad unit IDs | LevelPlay → Ad units (new units if compromised) |
| `CAP_HMAC_KEY` | Your cap API server — new signing key, update server + clients |
| Adsterra zone URLs | Adsterra publisher panel — regenerate zone links |
| `ADSTERRA_TELEMETRY_HMAC_KEY` | Telemetry backend |
| Firebase | If `google-services.json` leaked — Firebase Console → regenerate / restrict |

Then purge from git history (BFG or `git filter-repo`) if the repo was public.

## Current injection paths

| Layer | Mechanism |
|-------|-----------|
| Dart | `String.fromEnvironment('KEY')` — empty default |
| Release build | `tool/build_release_apk.sh` or `scripts/build_release_apk.sh` |
| Android manifest app key | Gradle `resValue` from env / `local.properties` / dart-define |
| Local dev | `export KEY=...` or `android/local.properties` (see `android/local.properties.template`) |

## Release without defines

- App **launches**; `AdManager` sets `_initialized = false` when `hasMonetizationConfig` is false.
- Log: `[AdManager.init] monetization config incomplete`
- No crash.

## Verify no literals in `lib/`

```bash
grep -rE 'YOUR_APP_KEY|adsterra\.com/zones|LEVELPLAY_APP_KEY=[^$]' lib/ || echo "PASS: no hardcoded ad keys in lib/"
```

## Rotation checklist (per incident)

1. Revoke old key in vendor dashboard.
2. Issue new key / zone URL.
3. Update CI secrets and local `.env` (from `.env.example`).
4. Rebuild: `./scripts/build_release_apk.sh`
5. Ship new APK; confirm `[LevelPlay] init success` on device with defines set.
