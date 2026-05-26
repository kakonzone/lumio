# Cleartext HTTP policy (R04)

**Audit artifact:** `docs/CLEARTEXT_AUDIT.txt` (`grep -rn "http://" lib/` — 137 matches at generation).

## Policy

| Category | Action | Examples |
|----------|--------|----------|
| **(a) IPTV HLS/TS** | Keep HTTP URLs in channel data; allow host in `network_security_config.xml` | `*.m3u8`, `starshare.net`, `198.195.239.50` |
| **(b) API / control plane** | Prefer HTTPS when remote; HTTP only for loopback / emulator dev | `api_service.dart` → `10.0.2.2:8080`, `CAP_BASE_URL` via dart-define |
| **(c) Debug / agent leftovers** | Remove from `lib/` | Removed `127.0.0.1:7565` ingest in `channel_hub_processor.dart` |

## Residual cleartext (justified)

| Location | URL pattern | Justification |
|----------|-------------|---------------|
| `lib/data/extra_channels.dart`, `user_paste_channels.dart`, `app_provider.dart`, `player_screen.dart` | Third-party IPTV origins | Providers publish HTTP-only HLS; HTTPS not available |
| `lib/services/api_service.dart` | `http://10.0.2.2:8080`, `http://localhost:8080` | Local Shelf dev server (`bin/dev_server.dart`); not used in release APK paths unless configured |
| `lib/services/background_service.dart` | `http://10.0.2.2:8080` fallback | Emulator default for background sync |
| `bin/dev_server.dart` | `http://localhost:$port` | Dev-only; not packaged in mobile `main()` |

## Android network security

- **Release:** `base-config cleartextTrafficPermitted="false"`; explicit `domain-config` allowlist for known IPTV CDN hosts (not wide subnet).
- **Debug:** `debug-overrides` permits cleartext for local QA against HTTP-only streams and emulator loopback.

## Migrations performed (Phase 8)

- Toffee CDN already HTTPS (`bldcmprod-cdn.toffeelive.com`) — no change.
- No production API endpoints migrated in this sprint (cap/telemetry use `CAP_BASE_URL` / `ADSTERRA_TELEMETRY_URL` dart-defines, typically HTTPS in CI).

## Verification

```bash
grep -rn "http://" lib/ | tee docs/CLEARTEXT_AUDIT.txt
grep -rn "127.0.0.1:7565" lib/   # expect 0 after Phase 8
```
