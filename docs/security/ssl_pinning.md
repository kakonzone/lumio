# SSL pinning rotation

Lumio pins TLS public keys via `--dart-define` (never commit real pin values).

## Required defines (release)

| Define | Purpose |
|--------|---------|
| `SSL_PIN_PRIMARY` | Primary SPKI SHA-256 (base64) |
| `SSL_PIN_BACKUP` | Backup pin for cert rotation |
| `SSL_PIN_STREAM_TOKEN_PRIMARY` | Optional override for stream-token API host |
| `SSL_PIN_STREAM_TOKEN_BACKUP` | Backup for stream-token host |

Host-specific pins (optional): `SSL_PIN_LEVELPLAY_*`, `SSL_PIN_ADSTERRA_*`, `SSL_PIN_SUPERSONIC_*`.

## Extract a pin from a live host

```bash
openssl s_client -connect YOUR_HOST:443 -servername YOUR_HOST </dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64
```

## Rotation procedure

1. Obtain the **backup** certificate’s SPKI pin before the primary cert expires.
2. Ship an app update with the new value in `SSL_PIN_BACKUP` (keep old primary until cutover).
3. After most users updated, swap: new cert → `SSL_PIN_PRIMARY`, next backup → `SSL_PIN_BACKUP`.
4. Verify on a staging device with `flutter run --release` and the new defines.

## CI

`release_apk.yml` passes `SSL_PIN_PRIMARY` and `SSL_PIN_BACKUP` from GitHub Actions secrets.

Release builds throw at startup if both global pins are missing (unless `LUMIO_SIDELOAD_DEV=true`).
