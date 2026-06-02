# HTTP → HTTPS audit (rc1)

Generated from `docs/release/http_urls.txt`.

## Category A — swapped to HTTPS in code

| Location | Action |
|----------|--------|
| `lib/screens/player_screen.dart` fallback demos | `http://198.195.239.50:8095/...` → `https://` same host |

## Category B — allowlisted (dev / legacy)

| File | Reason |
|------|--------|
| `lib/services/api_service.dart` | Android emulator `10.0.2.2` dev backend |
| `lib/services/background_service.dart` | Emulator fallback base URL |
| `lib/services/scanned_iptv_service.dart` | Third-party IPTV scan endpoints (HTTP-only) |
| `lib/provider/app_provider.dart` | Runtime `http→https` upgrade helper (no literal host) |
| `lib/screens/player_screen.dart` | Remaining holdouts if HTTPS probe fails |

## Category C — assets (not scanned by unit test)

`assets/data/scanned_iptv.m3u` and `assets/data/user_playlist.m3u` contain many HTTP stream URLs. Migrate via playlist refresh on GitHub, not in-app literals.

## Cloudflare proxy

Deferred — stream-token Worker `/v1/proxy` not implemented (per rc1 scope).
