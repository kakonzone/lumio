# Required dart-defines (release CI)

Set these as GitHub Actions secrets or in `secrets.json` for local release builds. Never commit real values.

## Stream & security

| Define | Secret name |
|--------|-------------|
| `STREAM_TOKEN_BASE_URL` | `STREAM_TOKEN_BASE_URL` |
| `SSL_PIN_PRIMARY` | `SSL_PIN_PRIMARY` |
| `SSL_PIN_BACKUP` | `SSL_PIN_BACKUP` |

## Monetag (rc1 names)

| Define | Secret name |
|--------|-------------|
| `MONETAG_ZONE_INTERSTITIAL` | `MONETAG_ZONE_INTERSTITIAL` |
| `MONETAG_ZONE_REWARDED` | `MONETAG_ZONE_REWARDED` |
| `MONETAG_ZONE_BANNER` | `MONETAG_ZONE_BANNER` |
| `MONETAG_ZONE_NATIVE` | `MONETAG_ZONE_NATIVE` |

Legacy names (`MONETAG_ONCLICK_ZONE`, etc.) still work if rc1 names are unset.

## Monetization (secrets.json)

`LEVELPLAY_APP_KEY`, `ADSTERRA_*`, `CAP_*`, `TOFFEE_SUBSCRIBER_TOKEN` — see `NEW_DART_DEFINES.env`.

## Legal (optional overrides)

| Define | Default |
|--------|---------|
| `PRIVACY_POLICY_URL` | `https://kakonzone.github.io/lumio/privacy.html` |
| `TERMS_OF_SERVICE_URL` | `https://kakonzone.github.io/lumio/terms.html` |
