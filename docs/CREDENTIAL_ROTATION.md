# Credential rotation (Phase 10)

After any secret appeared in git history, rotate at the provider and update CI `--dart-define` values only (never commit values).

## Expected credential types

| Credential | Provider | Dashboard |
|------------|----------|-----------|
| LevelPlay app key | ironSource LevelPlay | https://platform.ironsrc.com/ |
| LevelPlay ad units | LevelPlay → Ad units | Same |
| Adsterra zones / direct links | Adsterra | https://publishers.adsterra.com/ |
| Monetag zone IDs | Monetag / PropellerAds | Publisher dashboard |
| Stream provider creds | IPTV / CDN operator | Provider portal |
| `CAP_HMAC_KEY` | Lumio backend | Internal ops |
| `STREAM_TOKEN_BASE_URL` signing secret | Lumio token API | Internal ops |
| Firebase / `google-services.json` | Firebase Console | https://console.firebase.google.com/ |
| Release keystore | Local / CI secret store | Not in git |

## Rotation steps (each secret)

1. **Identify** — run `./scripts/audit_secrets.sh` (or review `gitleaks_report.json`).
2. **Revoke** old key at provider (disable zone or rotate app key).
3. **Issue** new key / zone URL.
4. **Update** CI secrets and `secrets.json` locally.
5. **Rebuild** `./tool/build_release_apk.sh`.
6. **Verify** device smoke (`docs/WORLD_CUP_RELEASE_SMOKE_TEST.md`).
7. **Confirm** old key returns 401/invalid in provider dashboard.

## Git history

If secrets were committed, see `scripts/purge_history.sh` — **do not run** without team approval (rewrites history).

Urgent stream creds: `docs/CREDENTIAL_ROTATION_URGENT.md`.
