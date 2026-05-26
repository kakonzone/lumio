# Telemetry split — Firebase vs ad networks (Phase 4 L4)

**Generated:** 2026-05-25

---

## Overview

| Destination | What | Client entry | Release when unset |
|-------------|------|--------------|-------------------|
| **Firebase Analytics** | LevelPlay impressions, funnel, caps fallback events | `lib/ads/analytics/ad_analytics.dart` | Events no-op if Firebase init failed |
| **Adsterra private API** | WebView / popunder / direct-link telemetry | `logAdsterraTelemetry()` → `AdsterraTelemetryService` | POST skipped if URL/key empty |
| **LevelPlay / IronSource** | Mediation SDK internal + revenue | `LevelPlayAdService`, dashboard | SDK handles; no Lumio POST |
| **Server cap API** | Per-device placement limits | `ServerCap` GET `/caps/{installId}` | Local + fail-closed if URL set but down |
| **Play Integrity** | — | **Disabled v1.0 (Option B)** | No `X-Integrity-Token`; cap sync uses install-ID + server HMAC/dedup only |

Lumio does **not** send Adsterra events to Firebase. LevelPlay revenue impressions are duplicated only into Firebase via `logLevelPlayImpression`.

---

## Firebase Analytics (`AdAnalytics`)

| Event (examples) | When |
|------------------|------|
| `app_open_substitute` | Cold-start interstitial substitute shown |
| `ad_impression` | LevelPlay display with revenue fields |
| `interstitial_shown` | Channel / exit interstitial |
| `channel_tap_slot` | First-tap rotator slot |
| `rewarded_complete` | Rewarded grant |
| `banner_impression` | HOME banner display |
| `adsterra_native_loaded` / `adsterra_banner_loaded` | WebView load (metadata only, not Adsterra POST) |
| `channel_click_count` | Session funnel |
| `cap_client_fallback` | Legacy name if server overlay fails |

**Config:** `google-services.json`, package `com.kakonzone.lumio`.

**Debug:** `[AdAnalytics]` lines only in `kDebugMode`.

---

## Adsterra private telemetry

| Field | Source |
|-------|--------|
| `installId` | `AdSafetyService` |
| `fingerprint` | `AdSafetyService` |
| `placement` / `format` | Call site (`popunder`, `direct_link`, …) |

**Config:** `ADSTERRA_TELEMETRY_URL`, `ADSTERRA_TELEMETRY_HMAC_KEY` — see `docs/ADSTERRA_TELEMETRY_API.md`.

**Gating:** `AdSafetyService.adsterraEnabled` (VPN fraud tier, RC `adsterra_enabled`).

---

## What never hits Lumio backends

| Data | Goes to |
|------|---------|
| LevelPlay bid / fill | IronSource / mediated networks |
| Adsterra script impressions | Adsterra CDN / publisher dashboard |
| User video URLs | IPTV origins (not Lumio server) |

---

## Operator checklist

1. Firebase project linked to app ID.  
2. Adsterra dashboard for zone revenue (separate from Firebase).  
3. Optional: `CAP_BASE_URL` + `ADSTERRA_TELEMETRY_URL` on same or different hosts.  
4. Do not expect Adsterra WebView events in Firebase Realtime — use private telemetry or Adsterra UI.
