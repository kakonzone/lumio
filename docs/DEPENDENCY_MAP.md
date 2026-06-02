# Lumio — dependency map (Phase 0)

**Generated:** 2026-05-28 post-audit sprint

## Bootstrap (`lib/main.dart`)

```
main()
  ├─ SslPinning.assertReleaseConfiguration()
  ├─ AdConfig.assertReleaseMonetization() + MonetagConfig.assertReleaseConfiguration()
  ├─ SecurityManager.initialize()
  ├─ FirebaseBootstrap → AdSafetyService.prefetchRemoteConfig()
  ├─ AdManager (singleton, post-frame in MainShell)
  └─ MultiProvider
       ├─ ChannelsProvider → RemoteChannelsService
       ├─ CoinsProvider → CoinEconomy
       ├─ AdsSettingsProvider → AdConsentService + IabConsentBridge
       └─ AppProvider → CatalogService, matches, news, stream health
```

## Screens → providers

| Screen | Primary state | Ads |
|--------|---------------|-----|
| `SplashScreen` | `AdConsentService` | preload via `AdManager` |
| `TvScreen` (HOME) | `AppProvider` | Adsterra native/banner, LevelPlay shell banner |
| `SportsScreen` / `LiveScreen` / `CategoriesScreen` | `AppProvider` | placement-specific Adsterra |
| `NewsScreen` | `AppProvider` + `NewsService` | news placements |
| `PlayerScreen` | local `Player` + `AppProvider` related | mid-roll, Monetag in-page (not background engine) |
| `FavoritesScreen` | `UserStateProvider` + `AppProvider` channels | list natives |
| `SpinWheelScreen` | `CoinsProvider` | LevelPlay rewarded |
| `AdsPrivacyScreen` | `AdsSettingsProvider` | consent revoke |

## Services → APIs

| Service | API / backend | Transport |
|---------|---------------|-----------|
| `StreamTokenService` | `STREAM_TOKEN_BASE_URL` `/v1/stream-token` | `SecureDio` (pinned) |
| `RemoteChannelsService` | `REMOTE_CHANNELS_URL` (CF Worker) | `SecureDio` + ETag |
| `CatalogService` | Worker + M3U + bundled assets | http + merge pipeline |
| `ToffeeCredentialsService` | `LUMIO_BACKEND_BASE_URL` | `SecureDio` + HMAC |
| `ServerCap` | `CAP_BASE_URL` | Dio |
| `WalletApiClient` | `/v1/wallet/*` (optional) | `SecureDio` |

## Ad network init

| Network | Init entry | Config |
|---------|------------|--------|
| LevelPlay | `LevelPlayAdService.init()` ← `AdManager.init` | `LEVELPLAY_*` dart-define |
| Unity | Mediation only (dashboard) | — |
| Adsterra | `AdsterraWebView`, `BackgroundAdEngine`, direct link | `ADSTERRA_*` |
| Monetag | `PropellerEngine` (do not refactor background engine) | `MONETAG_*` dart-define |

## Playback path

`openChannelPlayer` → `ChannelResolver.resolveForPlayback` → `StreamTokenService.fetchToken` (if protected) → `PlayerScreen`
