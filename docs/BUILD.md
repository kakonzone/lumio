# Lumio — build & ad config (Phase 7a)

Real keys never go in `lib/`, docs, or git. Use a local `secrets.json` (gitignored) or CI `--dart-define=KEY=$ENV_VAR`.

## 1. Bootstrap secrets

```bash
cp secrets.json.template secrets.json
# Fill every key — names must match lib/config/ad_config.dart exactly
```

Verify git ignores your file:

```bash
git check-ignore -v secrets.json
```

## 2. Debug run (device / emulator)

**Required:** pass defines at **build** time (compile-time constants). Plain `flutter run` shows every key `<unset>` and no ads.

```bash
flutter run --dart-define-from-file=secrets.json
```

Shortcut:

```bash
./scripts/flutter_run_with_ads.sh
```

VS Code / Cursor: run launch config **「Lumio (debug + ads)」** (`.vscode/launch.json`).

After editing `secrets.json`, stop the app and run again — **hot reload does not apply** `--dart-define`.

**Debug/profile ads:** set `"ADS_ENABLED": "true"` in `secrets.json`. Release builds enable ads without it.

**Success log (first lines):** `ADS_ENABLED=<set>`, `LEVELPLAY_APP_KEY=<set>`, `hasMonetizationConfig=<set>`.  
**Failure:** `ads blocked in non-release build` → missing `ADS_ENABLED` or wrong run command.

On cold start, logcat should include one line from `AdConfig.dumpRedacted()` (each key `<set>` or `<unset>`, never values).

## 3. Release APK

Before building, refresh the channel bundle and Android HTTP allowlist (release blocks cleartext except listed hosts):

```bash
python3 tool/gen_network_security_config.py
# optional: tool/user_playlist.m3u → assets
python3 tool/ingest_user_playlist.py
# optional: ~1000+ scanned channels offline in APK
python3 tool/build_scanned_iptv_m3u.py
```

```bash
flutter build apk --release --target-platform=android-arm64 \
  --dart-define-from-file=secrets.json \
  --dart-define=STREAM_TOKEN_BASE_URL=https://api.lumio.app \
  --dart-define=SSL_PIN_PRIMARY=base64_primary_spki_hash \
  --dart-define=SSL_PIN_BACKUP=base64_backup_spki_hash \
  --dart-define=PRIVACY_POLICY_URL=https://lumio.app/privacy \
  --dart-define=TERMS_OF_SERVICE_URL=https://lumio.app/terms \
  --dart-define=CONTACT_EMAIL=support@lumio.app \
  --dart-define=DATA_DELETION_URL=https://lumio.app/data-deletion
```

Or use `tool/build_release_apk.sh` (requires `STREAM_TOKEN_BASE_URL` and legal defines).

CI example (no committed file):

```bash
flutter build apk --release \
  --dart-define=LEVELPLAY_APP_KEY="$LEVELPLAY_APP_KEY" \
  --dart-define=CAP_BASE_URL="$CAP_BASE_URL"
```

Alternative: `tool/build_release_apk.sh` with exported env vars (see `docs/SECRETS.md`).

## Key reference

Names in the left column are **dart-define** keys. Legacy nicknames from spreadsheets are noted; use the dart-define name in `secrets.json`.

| Dart-define key | Where to obtain | Required for `hasMonetizationConfig` |
|-----------------|-----------------|----------------------------------------|
| `ADS_ENABLED` | Local QA (`true` in debug) | Debug/profile ad gate only |
| `ADS_TEST_MODE` | Legacy alias for `ADS_ENABLED` | Optional |
| `LEVELPLAY_APP_KEY` | [LevelPlay / IronSource](https://platform.ironsrc.com/) → App → App key | Yes |
| `LEVELPLAY_INTERSTITIAL_AD_UNIT` | LevelPlay → Ad units → Interstitial | Yes (interstitial + banner) |
| `LEVELPLAY_BANNER_AD_UNIT` | LevelPlay → Banner | Yes |
| `ADSTERRA_DIRECT_LINK` | [Adsterra](https://publishers.adsterra.com/) → Direct link | One of direct **or** WebView pair |
| `ADSTERRA_DIRECT_LINKS` | Pipe-separated direct links (`url1\|url2\|…`) — **random** pick on each **1st channel tap** | Preferred over single `ADSTERRA_DIRECT_LINK` |
| `ADSTERRA_POPUNDER_SCRIPT_URL` | Adsterra zone → script `.js` URL | WebView pair (with `*_BASE_URL`) |
| `ADSTERRA_POPUNDER_BASE_URL` | Origin for WebView `<base href>` (e.g. `https://pl….effectivecpmnetwork.com/`) | Same pair |
| `ADSTERRA_NATIVE_INVOKE_URL` | Native banner → invoke.js | Alternate WebView pair |
| `ADSTERRA_NATIVE_CONTAINER_ID` | Container div id from zone snippet | With native pair |
| `ADSTERRA_NATIVE_BASE_URL` | Native zone origin | With native pair |
| `ADSTERRA_BANNER728_INVOKE_URL` | 728×90 / highperformanceformat invoke | Alternate WebView pair |
| `ADSTERRA_BANNER728_CONTAINER_ID` | Zone key / container id | With 728 pair |
| `ADSTERRA_BANNER728_BASE_URL` | Banner zone origin | With 728 pair |
| `ADSTERRA_SOCIAL_SCRIPT_URL` | Social bar script | Optional surface |
| `ADSTERRA_SOCIAL_BASE_URL` | Social bar origin | Optional |
| `CAP_BASE_URL` | Backend ops — GET `{base}/caps/{installId}` | Release server caps (see `docs/SERVER_CAP_API.md`) |
| `CAP_HMAC_KEY` | Backend ops — cap HMAC | With `CAP_BASE_URL` |
| `CAP_LOCAL_ONLY_MODE` | Set `"true"` for release/sideload QA when cap backend is not ready | Skips server GET; uses local `AdTriggerManager` caps only (see `server_cap.dart`) |
| `ADSTERRA_TELEMETRY_URL` | Private telemetry POST host | Optional v1.0 |
| `ADSTERRA_TELEMETRY_HMAC_KEY` | Telemetry signing secret | With telemetry URL |
| `STREAM_TOKEN_BASE_URL` | HTTPS API root for `POST /v1/stream-token` | **Required** release (protected streams) |
| `SSL_PIN_PRIMARY` | SPKI SHA-256 (base64) for stream-token API host | **Required** release (or `SSL_PIN_STREAM_TOKEN_*`) |
| `SSL_PIN_BACKUP` | Backup pin for cert rotation | Strongly recommended |
| `PRIVACY_POLICY_URL` | Public privacy page | Release / ad compliance |
| `TERMS_OF_SERVICE_URL` | Public terms page | Release |
| `CONTACT_EMAIL` | Support email (`mailto:`) | Release |
| `DATA_DELETION_URL` | Play Console data deletion page | Release |
| `DIAGNOSTICS_ENABLED` | `true` unlocks zone validator UI | Debug QA only |

### Legacy name → dart-define (do not use legacy names in JSON)

| Spreadsheet / old name | Use instead |
|------------------------|-------------|
| `LEVELPLAY_INTERSTITIAL_UNIT` | `LEVELPLAY_INTERSTITIAL_AD_UNIT` |
| `LEVELPLAY_BANNER_UNIT` | `LEVELPLAY_BANNER_AD_UNIT` |
| `ADSTERRA_POPUNDER_ZONE` | `ADSTERRA_POPUNDER_SCRIPT_URL` + `ADSTERRA_POPUNDER_BASE_URL` |
| `ADSTERRA_BANNER_ZONE` | `ADSTERRA_BANNER728_INVOKE_URL` + `ADSTERRA_BANNER728_BASE_URL` (+ container id) |
| `TELEMETRY_URL` | `ADSTERRA_TELEMETRY_URL` |

## Minimum viable `secrets.json`

Release ads need LevelPlay app key + all three ad units + **either** `ADSTERRA_DIRECT_LINK` **or** at least one complete Adsterra script+base pair (popunder, native, or 728).

## Related docs

- `docs/SECRETS.md` — env / `build_release_apk.sh`
- `docs/SECRETS_ENV.md` — Gradle `local.properties`
- `docs/DEVICE_TEST_RESULTS.md` — Phase 7a smoke matrix
- `docs/PHASE7_BUGS.md` — deferred log / config gaps
