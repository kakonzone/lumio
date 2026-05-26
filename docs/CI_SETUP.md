# GitHub Actions CI setup (R06)

## Workflows

| File | Trigger | Purpose |
|------|---------|---------|
| `.github/workflows/ci.yml` | `push`, `pull_request` | `flutter analyze --fatal-warnings`, `flutter test` |
| `.github/workflows/release_apk.yml` | `workflow_dispatch` only | Signed release APK artifact (private) |

## Repository secrets (Settings → Secrets → Actions)

Placeholder names only — **never commit values**.

| Secret | Used by |
|--------|---------|
| `LEVELPLAY_APP_KEY` | release APK dart-defines |
| `ADSTERRA_DIRECT_LINK` | release APK |
| `ADSTERRA_NATIVE_INVOKE_URL` | release APK |
| `ADSTERRA_NATIVE_BASE_URL` | release APK |
| `CAP_BASE_URL` | release APK |
| `CAP_HMAC_KEY` | release APK |
| `TOFFEE_SUBSCRIBER_TOKEN` | release APK |
| `KEYSTORE_BASE64` | release signing |
| `KEYSTORE_PASSWORD` | release signing |
| `KEY_ALIAS` | release signing |
| `KEY_PASSWORD` | release signing |
| `GOOGLE_SERVICES_JSON` | optional; full JSON for Firebase/Crashlytics build |

CI job does **not** need monetization secrets — tests run without `secrets.json`.

## Local parity

```bash
flutter analyze --fatal-warnings
flutter test
```

## Release artifact

Manual workflow uploads `app-release.apk` as a workflow artifact (not a public GitHub Release).
