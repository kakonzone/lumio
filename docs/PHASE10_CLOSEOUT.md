# Phase 10 P0 — code close-out

**Status:** Client code complete. **Ops** items below must be done before World Cup release.

## Implemented (in repo)

| Task | Deliverable |
|------|-------------|
| 1 Stream token | `StreamTokenService`, `ChannelResolver`, release assert, tests, `BACKEND_STREAM_TOKEN_CONTRACT.md` |
| 2 SSL pins | `SslPinning`, `SSL_PIN_PRIMARY`/`BACKUP`, startup fail-fast, tests |
| 3 Legal | `LegalConfig`, Ads & privacy + consent links, `assets/legal/*`, `LEGAL_HOSTING.md` |
| 4 Secrets | `audit_secrets.sh`, `.gitleaks.toml`, `CREDENTIAL_ROTATION.md`, `purge_history.sh` (manual) |
| 5 Zones | `ZoneValidator`, diagnostics button, `AD_ZONE_INVENTORY.md` |

## Verification commands

```bash
flutter test
flutter analyze lib/services/stream_token_service.dart lib/security/ssl_pinning.dart lib/config/legal_config.dart lib/ads/diagnostics/zone_validator.dart
```

Per-task adb filters: `docs/PHASE10_TASK_[1-5]_VERIFICATION.md`.

## Ops checklist (you)

- [ ] Deploy `POST /v1/stream-token` backend; set `STREAM_TOKEN_BASE_URL` in CI
- [ ] Extract and set `SSL_PIN_PRIMARY` + `SSL_PIN_BACKUP` (and per-network pins if used)
- [ ] Publish privacy / terms / data-deletion HTML at `lumio.app`
- [ ] Run `./scripts/audit_secrets.sh`; rotate any findings; optional `filter-repo` with approval
- [ ] Device: `DIAGNOSTICS_ENABLED=true` → Validate All Zones; smoke `docs/WORLD_CUP_RELEASE_SMOKE_TEST.md`

## Release build

```bash
./tool/build_release_apk.sh
# Requires STREAM_TOKEN_BASE_URL, legal URLs, LevelPlay, Adsterra, CAP_* (see docs/BUILD.md)
```
