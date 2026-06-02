# SSL Pinning

Logic: `lib/security/ssl_pinning.dart`  
Wiring: `lib/network/secure_dio.dart` → Dio `IOHttpClientAdapter.validateCertificate`  
Startup: `SslPinning.assertReleaseConfiguration()` in `main()` before HTTP clients.

## Pinned hosts

- `app.levelplay.com`
- `init.supersonic.com`
- `adsterra.com`
- `STREAM_TOKEN_BASE_URL` host

## Required dart-defines

**Stream token API (pick one style):**

- `SSL_PIN_PRIMARY` + `SSL_PIN_BACKUP` (global fallback for token host), **or**
- `SSL_PIN_STREAM_TOKEN_PRIMARY` + `SSL_PIN_STREAM_TOKEN_BACKUP`

**Per ad network host:**
- `SSL_PIN_LEVELPLAY_PRIMARY`
- `SSL_PIN_LEVELPLAY_BACKUP`
- `SSL_PIN_SUPERSONIC_PRIMARY`
- `SSL_PIN_SUPERSONIC_BACKUP`
- `SSL_PIN_ADSTERRA_PRIMARY`
- `SSL_PIN_ADSTERRA_BACKUP`

## Extracting SPKI pins

```bash
openssl s_client -connect api.lumio.app:443 -showcerts </dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | base64
```

Paste into `--dart-define=SSL_PIN_PRIMARY=...` and `SSL_PIN_BACKUP=...`. No `.pem` in `assets/`.

## Runtime behavior

- **Release / `RELEASE_MODE=true`:** pinned hosts fail-closed on mismatch; logcat `[SSL] pin verified` or `[SSL] pin mismatch — connection rejected`.
- **Debug/profile:** pinning skipped (`SslPinning.validateCertificate` returns true).
- **Unpinned hosts** in release use normal system trust.

## Rotation

- Review every 30 days.
- Rotate backup first, then promote to primary after certificate change.
