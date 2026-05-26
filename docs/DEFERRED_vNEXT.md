# Deferred to vNext (removed stubs in Phase 4)

Items intentionally **not** shipped in Phase 1. Re-add with full implementation, not placeholder timers or no-op HTTP.

| Feature | Was | vNext work |
|---------|-----|------------|
| **Background headless Adsterra** | `background_ad_engine.dart` (removed Phase 4) | Re-add **`flutter_inappwebview`** + headless rotation; Wi‑Fi-only; battery check; `AdTriggerManager` caps; RC `background_webview_enabled`. **Task 11:** dependency removed until this ships — all visible Adsterra uses `webview_flutter` only. |
| **Private Adsterra telemetry** | Shipped: `adsterra_telemetry_client.dart` + `ADSTERRA_TELEMETRY_URL` | Backend ingest + dashboard; optional batching |
| **LevelPlay native widget** | `ad_native_widget.dart` (unused thin wrapper) | Use LevelPlay native when SDK supports it, or keep `AdsterraNativeBanner` via `AdListInjector` only |

## Current replacements (Phase 4)

- Adsterra events: `logAdsterraTelemetry()` — debug print + release POST when `ADSTERRA_TELEMETRY_URL` is set (`docs/ADSTERRA_TELEMETRY_API.md`).
- List native ads: `AdListInjector` + `AdsterraNativeBanner` in `lib/ads/adsterra/adsterra_native.dart`.
