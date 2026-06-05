# Secrets and release build variables

Never commit real keys. Use `~/.gradle/gradle.properties`, `android/local.properties`, or shell env vars.

## Appwrite (no API key in the app)

The mobile app uses **anonymous / Guests Read** only. Do **not** put an Appwrite API key in `secrets.json`, dart-defines, or source.

**Console (one-time):**

1. Delete any API key that was pasted in chat or committed — **Console → API keys → Delete**.
2. **Databases → `iptv_main` → `channels` → Settings → Permissions → Read → role `Guests` (any).**
3. Same **Read → Guests** on collection **`app_config`**.

**`secrets.json` — Appwrite keys only (no `APPWRITE_API_KEY`):**

| Key | Example |
|-----|---------|
| `APPWRITE_PROJECT_ID` | `191876000995145` |
| `APPWRITE_ENDPOINT` | `https://nyc.cloud.appwrite.io/v1` |
| `APPWRITE_DATABASE_ID` | `iptv_main` |
| `APPWRITE_CHANNELS_COLLECTION_ID` | `channels` |
| `APPWRITE_APP_CONFIG_COLLECTION_ID` | `app_config` |

Playlist fallback (`playlists` / document `main`) and featured World Cup cards (`featured_live_events` in `app_config`) use **code defaults** in `lib/config/appwrite_config.dart` — not required in `secrets.json`. See `docs/APPWRITE_WORLD_CUP_CARDS.md` for daily JSON updates.

Implementation: `AppwriteService` builds `Client` with endpoint + project only (`lib/services/appwrite_service.dart`).

## Required for `tool/build_release_apk.sh`

| Variable | Example (redacted) | Dart define |
|----------|-------------------|-------------|
| `LEVELPLAY_APP_KEY` | `abc123...` | `LEVELPLAY_APP_KEY` |
| `LEVELPLAY_INTERSTITIAL_AD_UNIT` | `DefaultInterstitial` | `LEVELPLAY_INTERSTITIAL_AD_UNIT` |
| `LEVELPLAY_BANNER_AD_UNIT` | `DefaultBanner` | `LEVELPLAY_BANNER_AD_UNIT` |
| `CAP_BASE_URL` | `https://api.example.com` | `CAP_BASE_URL` |
| `CAP_HMAC_KEY` | `hex-or-base64-secret` | `CAP_HMAC_KEY` |

**Adsterra (at least one):**

- `ADSTERRA_DIRECT_LINK=https://...` **or**
- `ADSTERRA_POPUNDER_SCRIPT_URL` + `ADSTERRA_POPUNDER_BASE_URL` **or**
- `ADSTERRA_NATIVE_INVOKE_URL` + `ADSTERRA_NATIVE_BASE_URL` **or**
- `ADSTERRA_BANNER728_INVOKE_URL` + `ADSTERRA_BANNER728_BASE_URL`

## Toffee streaming (R01)

| Variable | Dart define | Purpose |
|----------|-------------|---------|
| `TOFFEE_SUBSCRIBER_TOKEN` | `TOFFEE_SUBSCRIBER_TOKEN` | JWT from Toffee session — **never commit** |

Add to `secrets.json` (via `secrets.json.template`). Read at compile time by `AdConfig.toffeeSubscriberToken` and assembled in `lib/network/toffee_headers.dart`.

If missing, Toffee CDN requests send cookie prefix only (streams may 403 until set).

**After any leak:** rotate token at Toffee provider and rewrite git history — `docs/GIT_HISTORY_REWRITE.md`.

## Optional

| Variable | Purpose |
|----------|---------|
| `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER` | **OFF for v1.0** (Option B). Set only when shipping v1.1 Option A — see `docs/PLAY_INTEGRITY_OPTION_B.md` |
| `ADSTERRA_TELEMETRY_URL` / `ADSTERRA_TELEMETRY_HMAC_KEY` | Private telemetry POST |
| `ADS_ENABLED=true` | **Required for debug/profile ad QA** (safe default: off) |
| `ADS_TEST_MODE=true` | Legacy alias for `ADS_ENABLED` in non-release |

## Firebase

Place `android/app/google-services.json` from Firebase Console (gitignored in CI; present locally for release).

## Example

```bash
export LEVELPLAY_APP_KEY='YOUR_KEY'
export LEVELPLAY_INTERSTITIAL_AD_UNIT='DefaultInterstitial'
export LEVELPLAY_BANNER_AD_UNIT='DefaultBanner'
export CAP_BASE_URL='https://your-cap-host.example'
export CAP_HMAC_KEY='your-hmac-secret'
export ADSTERRA_DIRECT_LINK='https://...'
./tool/build_release_apk.sh
```

See also `docs/SECRETS_ENV.md` for Gradle/local.properties parity.
