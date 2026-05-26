# L1 — Ads layer cleanup (Phase 4)

**Generated:** 2026-05-25

---

## Removed

| Item | Files |
|------|-------|
| Debug NDJSON `adDebugLog()` file writes | Removed; stub logs via `debugPrint` in `kDebugMode` only |
| `#region agent log` blocks | `lib/ads/ad_manager.dart`, `lib/ads/adsterra/adsterra_webview.dart` |
| `print()` in banner listener | `lib/widgets/ad_banner_widget.dart` → `kDebugMode` `debugPrint` |

---

## Scanned — no action

| Area | Result |
|------|--------|
| Block-commented dead code (`/* */`, commented-out statements) | **None** in `lib/ads/**` |
| `lib/services/*ad*`, `ironsource`, `server_cap` | **None** |
| Unity SDK duplicate | Already documented in `channel_tap_ad_rotator.dart` header (kept — explains architecture) |

---

## Retained (intentional)

| Item | Why |
|------|-----|
| `logAdsterraTelemetry()` | Production telemetry path |
| `export '../services/ironsource_service.dart'` | Public API re-export |
| Section headers in `ad_config.dart` | Navigation aids |
