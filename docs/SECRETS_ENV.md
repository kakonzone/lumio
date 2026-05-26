# Secrets & compile-time configuration

Never commit real keys. Use **`--dart-define`**, **`android/local.properties`**, or CI environment variables.

## Resolution order (Android `LEVELPLAY_APP_KEY`)

1. `android/local.properties` → `LEVELPLAY_APP_KEY`
2. Environment variable `LEVELPLAY_APP_KEY`
3. Flutter `--dart-define=LEVELPLAY_APP_KEY=...` (Gradle parses `dart-defines`)

Dart reads the same name via `String.fromEnvironment('LEVELPLAY_APP_KEY')`.

## Required for production ads (LevelPlay)

| Env / dart-define | Former location (redacted) | Purpose |
|-------------------|---------------------------|---------|
| `LEVELPLAY_APP_KEY` | `ad_config.dart`, `build.gradle.kts`, `strings.xml` | IronSource app key |
| `LEVELPLAY_INTERSTITIAL_AD_UNIT` | `ad_config.dart` | Interstitial unit |
| `LEVELPLAY_REWARDED_AD_UNIT` | `ad_config.dart` | Rewarded unit |
| `LEVELPLAY_BANNER_AD_UNIT` | `ad_config.dart` | Banner unit |

## Adsterra zones (optional — empty disables surface)

| Env / dart-define | Purpose |
|-------------------|---------|
| `ADSTERRA_DIRECT_LINK` | Direct link URL |
| `ADSTERRA_SMARTLINK_URL` | Smartlink |
| `ADSTERRA_POPUNDER_SCRIPT_URL` | Popunder script |
| `ADSTERRA_POPUNDER_BASE_URL` | Popunder WebView base |
| `ADSTERRA_NATIVE_INVOKE_URL` | Native invoke.js |
| `ADSTERRA_NATIVE_CONTAINER_ID` | Native container id |
| `ADSTERRA_NATIVE_BASE_URL` | Native base |
| `ADSTERRA_SOCIAL_SCRIPT_URL` | Social bar script |
| `ADSTERRA_SOCIAL_BASE_URL` | Social bar base |
| `ADSTERRA_BANNER728_INVOKE_URL` | 728 banner script |
| `ADSTERRA_BANNER728_CONTAINER_ID` | 728 container id |
| `ADSTERRA_BANNER728_BASE_URL` | 728 base |

## Server / telemetry (already env-only)

| Env / dart-define | Purpose |
|-------------------|---------|
| `CAP_BASE_URL` | Server cap API |
| `CAP_HMAC_KEY` | Cap HMAC |
| `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER` | GCP project number for Play Integrity (Android); see `docs/PLAY_INTEGRITY_SERVER.md` |
| `ADSTERRA_TELEMETRY_URL` | Private telemetry endpoint |
| `ADSTERRA_TELEMETRY_HMAC_KEY` | Telemetry HMAC |
| `LUMIO_HMAC_SECRET` | API request signing (`security_config.dart`) |

## Example release build

```bash
export LEVELPLAY_APP_KEY='***'
export LEVELPLAY_INTERSTITIAL_AD_UNIT='***'
export LEVELPLAY_REWARDED_AD_UNIT='***'
export LEVELPLAY_BANNER_AD_UNIT='***'
./tool/build_release_apk.sh
```

Or add keys to `android/local.properties` and pass only Adsterra/cap defines on the command line.
