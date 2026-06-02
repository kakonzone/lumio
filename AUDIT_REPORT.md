# Lumio Sports TV — Forensic Technical & Business Audit

**Audit date:** 2026-05-28  
**Last updated:** 2026-06-02 **rev.5** — **Section 25** (GitHub-only catalog, split APK 32/64, ads secrets validation, matcher model); **Section 24** UI/size; **Section 23** sideload ads  
**Scope:** Full repo (`lib/`, `android/`, `assets/`, `pubspec.yaml`, Gradle, manifests, docs)  
**Distribution model:** Sideload APK (not Play Store) — Facebook / WhatsApp / Telegram / landing page  
**Monetization focus:** IronSource LevelPlay + Unity (mediation only) + Adsterra + Monetag  
**Infrastructure note:** Cloudflare usage audited — see **Section 13**

**Method:** Static code review + build artifacts on disk + fix-sprint verification (`flutter test` 113/113). No production backend access. Values marked **ESTIMATE** where not measured on device.

### Table of contents

| Section | Topic |
|---------|--------|
| 1 | Project health snapshot |
| 2 | Page-by-page features (+ splash, drawer, favorites, spin wheel) |
| 3 | Ad integration (LevelPlay, Unity, Adsterra, Monetag) |
| 4 | Live streaming |
| 5 | Security |
| 6 | Performance & UX |
| 7 | Tier-1 readiness |
| 8 | User acquisition |
| 9 | Revenue projection |
| 10 | Gap analysis (P0/P1/P2 + Phase 10) |
| 11 | Code quality |
| 12 | Final verdict |
| 13 | Cloudflare |
| 14 | Firebase & remote services |
| 15 | Monetization beyond ads (coins, ad-free — no store IAP) |
| 16 | Native Android, CI/CD, release pipeline |
| 17 | Key dependencies |
| 18 | Documentation & ops index |
| 19 | Payment rails (Payoneer / crypto) |
| 20 | Phase 10 P0 close-out status |
| 21 | Audit coverage checklist |
| 22 | Post-audit fix sprint (18-item protocol) |
| 23 | Sideload ads verification (2026-06-01) |
| 24 | Product UI, size & performance sprint (2026-06-01) |
| 25 | Catalog, APK split, ads & matcher sprint (2026-06-02) |

---

## SECTION 1 — Project Health Snapshot

| Metric | Value | Evidence |
|--------|-------|----------|
| Flutter SDK | **3.41.6** (stable) | `flutter --version` |
| Dart SDK | **3.11.4** | `flutter --version` |
| compileSdk / targetSdk / minSdk | **36 / 36 / 21+** | `minSdk = maxOf(21, flutter.minSdkVersion)` — **Android 5.0 (Lollipop)+** (`android/app/build.gradle.kts`) |
| lib `.dart` files | **157** | `find lib -name '*.dart'` (post fix-sprint) |
| lib LOC (approx.) | **~36,000+** | `wc -l` on `lib/**/*.dart` (new services/providers) |
| State management | **Provider** (`MultiProvider`) | `lib/main.dart` — `ChannelsProvider`, `CoinsProvider`, `AdsSettingsProvider`, `AppProvider` |
| Architecture | **Pragmatic layered monolith** — screens + `AppProvider` god-state + ad singletons | No Clean/MVVM boundaries; ad stack is well-factored into `lib/ads/` |
| Folder structure score | **6/10** | Good `lib/ads/`, `lib/services/`, `lib/security/` split; undermined by 3.5k+ LOC god files |
| TODO/FIXME in `lib/` + `android/` | **0** matches | `rg TODO\|FIXME` — none found |
| Unit/widget tests | **113 passing** | `flutter test` (2026-05-28) |
| Dead code | **Low–medium** | Duplicate `ironsource_service` paths (`lib/services/` vs `lib/ads/`); large embedded channel catalogs |
| **Package name** | `com.kakonzone.lumio` | `android/app/build.gradle.kts:100-101` |
| **Pub package** | `lumio_tv` v`1.0.0+1` | `pubspec.yaml:1-3` |
| **Ship target** | **Android APK (primary)** | `media_kit_libs_android_video`; sideload distribution |
| **iOS / desktop in repo** | **Present but not product focus** | `macos/`, `ios/` folders exist; audit scope = Android ship path |
| **Test files** | **39** Dart files under `test/` | `find test -name '*.dart'` |
| **Docs** | **95** Markdown files under `docs/` | includes Phase 10, smoke tests, secrets |
| **CI** | **GitHub Actions** — analyze + test on Flutter 3.41.6 | `.github/workflows/ci.yml` |
| **Release CI** | **release_apk.yml** present | `.github/workflows/release_apk.yml` |
| **Unused import scan** | **Not run in this audit** | Use `dart fix --dry-run` / analyzer before release |
| **Phase 10 (client)** | **Code complete** | `docs/PHASE10_CLOSEOUT.md` — ops items remain |
| **18-item fix sprint** | **Client complete** (partial god-file split) | `FIX_REPORT.md`, `BACKEND_CHECKLIST.md`, `NEW_DART_DEFINES.env` |

---

## SECTION 2 — Page-by-Page Feature Inventory

Navigation shell: `lib/main.dart:190-195` — `IndexedStack` with five tabs.

### HOME (`TvScreen`)

| Item | Detail |
|------|--------|
| **File** | `lib/screens/tv_screen.dart` (~1.9k+ LOC) |
| **Shell** | Search bar → **`HomePromoCarousel`** → sub-tabs **Home / Live / Today / Soon** (gradient pills + icons) |
| **Promo carousel** | FIFA WC26 asset banners + legacy gradient slides; tap → Sports / Live tab / Entertainment (`lib/widgets/home_promo_carousel.dart`) |
| **Browse grid** | **`HomeCategoryGrid`** — 3×2 gradient category tiles, emoji, LIVE pulse, channel counts (`lib/widgets/home_category_grid.dart`) |
| **All Live Events** | Gradient match cards, team flags (`TeamAvatar`), tap → channel dialog — **all links unlocked** (no match-started / health gate) |
| **Schedules** | **FootyStream** `/pk` + `/today` merged with ESPN/Cricbuzz via `ScheduleMerge` + `LiveEventsService` (`lib/services/footystream_service.dart`) |
| **Channel matching** | `MatchChannelMatcher.channelPoolFor` — Sports + regional cats (BD/PK/IN/EN); team name in channel metadata scoring |
| **Working** | Category drill-down, favorites hooks, `openChannelPlayer`, fast catalog + background full merge (`AppProvider.init`) |
| **Ads** | `AdsterraNativeBanner`, `AdsterraBanner728` (`home_bottom_banner`), `FloatingNativeCard` (`home_floating_native`), LevelPlay banner via shell |
| **Loading / error** | **Yes** — `RefreshIndicator` + `ChannelListSkeleton` |
| **Pull-to-refresh** | **Yes** |
| **Offline cache** | **Partial** — GitHub M3U cached 1h (`SpecialLinkConfig.gitunCacheTtl`) + in-memory catalog; no full offline playback |
| **Skeleton loaders** | **Yes** |

### SPORTS (`SportsScreen`)

| Item | Detail |
|------|--------|
| **File** | `lib/screens/other_screens.dart` (Sports section ~line 180+) |
| **Working** | Live scores, match grouping, channel shortcuts, sports-priority sorting |
| **Ads** | `AdsterraBanner728` (`sports_top`), injected natives, `FloatingNativeCard` (`sports_floating_native`) |
| **Loading / error** | **Yes** — skeletons + refresh |
| **Pull-to-refresh** | **Yes** (`RefreshIndicator` ~235) |
| **Skeleton** | **Yes** (`ChannelListSkeleton`, `CategoryGridSkeleton`) |

### LIVE (`LiveScreen`)

| Item | Detail |
|------|--------|
| **File** | `lib/screens/other_screens.dart` (Live section) |
| **Working** | Live events list, stream links, tap-to-play |
| **Ads** | `AdsterraBanner728` (`live_top`), list natives |
| **Loading / error** | **Yes** |
| **Pull-to-refresh** | **Yes** |
| **Skeleton** | **Yes** |

### NEWS (`NewsScreen`)

| Item | Detail |
|------|--------|
| **File** | `lib/screens/news_screen.dart`, `lib/screens/news_article_reader_screen.dart` |
| **Working** | RSS/API news feed, article reader, ad injection in list (`lib/ads/ad_placement_news.dart`) |
| **Ads** | `AdsterraNativeBanner`, sticky `AdsterraBanner728` (`news_top_sticky`) |
| **Loading / error** | **Yes** — refresh on feed |
| **Pull-to-refresh** | **Yes** |
| **Skeleton** | **Partial** (list-level; not as heavy as HOME) |

### CATEGORIES (`CategoriesScreen`)

| Item | Detail |
|------|--------|
| **File** | `lib/screens/other_screens.dart` (`CategoriesScreen` ~1100+ LOC), drill-down `lib/screens/category_channels_screen.dart` |
| **Working** | **Gradient genre cards** (per-category color), LIVE badges, “All Channels” hero banner, Pakistan wide card, counts from `AppProvider.byCategory` |
| **Bottom nav** | **`MainShellBottomNav`** — per-tab accent gradients (Home/Sports/Live/News/Browse) |
| **Missing / weak** | No server-driven category CMS; catalog still largely embedded in `app_provider.dart` |
| **Loading / error** | **Yes** |
| **Pull-to-refresh** | **Yes** |
| **Skeleton** | **Yes** (`CategoryGridSkeleton`) |

### PLAYER (not a tab — critical path)

| Item | Detail |
|------|--------|
| **File** | `lib/screens/player_screen.dart` (**3,181 LOC**) + `player_screen_widgets.dart` (**366 LOC**) |
| **Working** | `media_kit` playback, multi-backup URLs, PiP, failover (max 3), buffering watchdog 12s |
| **Ads** | `AdsterraNativeBanner`, `PropellerInPagePushBanner` (Monetag), mid-roll / video ad overlays |
| **Error handling** | **Yes** — failover + Crashlytics hooks (when Firebase wired) |
| **PiP** | **Yes** | `AndroidManifest.xml:51` — `supportsPictureInPicture` |
| **Background audio** | **Yes** | `audio_service` + `lumio_audio_service.dart` |

### SPLASH (`SplashScreen`)

| Item | Detail |
|------|--------|
| **File** | `lib/screens/splash_screen.dart` |
| **Working** | Consent gate → branding → `AdManager.preloadFromSplash`, direct link, background engine schedule |
| **Ads** | Splash-min delay before ads (`AdConfig.splashMinMsBeforeAds` = 5000 ms) |
| **Missing** | Full CMP; splash interstitial is Adsterra direct-link path when configured |

### DRAWER / secondary destinations (`LumioAppDrawer`)

| Item | Detail |
|------|--------|
| **File** | `lib/widgets/app_drawer.dart` |
| **Working** | Category shortcuts, theme toggle, Ads & privacy, Share app (`ShareCampaignService`), diagnostics (7× version tap if `DIAGNOSTICS_ENABLED`) |
| **Routes** | Favorites, Spin wheel, etc. via `AppDrawerDestination` — not all are bottom-nav tabs |

### FAVORITES (`FavoritesScreen`)

| Item | Detail |
|------|--------|
| **File** | `lib/screens/favorites_screen.dart` |
| **Working** | Persisted favorites via `AppProvider` / SharedPreferences |
| **Ads** | List native injection per `AdListScreen.favorites` density |
| **Pull-to-refresh** | **Partial** — depends on parent refresh of channel catalog |

### SPIN WHEEL (`SpinWheelScreen`)

| Item | Detail |
|------|--------|
| **File** | `lib/screens/spin_wheel_screen.dart` |
| **Working** | Coin balance UI, rewarded-gated spin (`RewardedFeatures.spinWheel`) |
| **Monetization** | LevelPlay **rewarded** required before spin — `rewarded_gate.dart:18` |
| **Economy** | Prizes via `CoinEconomy` — `coin_economy.dart` |

---

## SECTION 3 — Ad Integration Audit

### 3.1 IronSource LevelPlay

| Check | Result | Evidence |
|-------|--------|----------|
| Package | **`unity_levelplay_mediation: 9.2.0`** | `pubspec.yaml:58-59` |
| Initialization | **Implemented** — `LevelPlayAdService.init()` | `lib/services/ironsource_service.dart:100-118` |
| Manifest key | **Present** — `com.ironsource.sdk.ApplicationKey` → `@string/levelplay_app_key` | `android/app/src/main/AndroidManifest.xml:108-111` |
| Formats | Interstitial, rewarded, banner | `LevelPlayInterstitialAd`, `LevelPlayRewardedAd`, `LevelPlayBannerAdView` in `ironsource_service.dart` / `ad_banner_widget.dart` |
| Init gating | Skipped if keys **empty or template** (`hasValidLevelPlay*`) or `adsBlockedInDebug` | `ironsource_service.dart`, `ad_config.dart` `isPlaceholderSecret` |
| Ship keys | **Configured** in local `secrets.json` (gitignored) — LevelPlay app key + 3 units; Adsterra 4 WebView zones; Monetag 5 zones | `tool/build_release_apk.sh` monetization validator |
| Build guard | **Fails** on `আপনার_*`, `example.com`, or no real monetization stack | `tool/build_release_apk.sh` (2026-06-02) |
| Release assert | `AdConfig.assertReleaseMonetization()` in `main()` | Rejects placeholder URLs / template LevelPlay in release |

### 3.2 Unity Ads mediation

| Check | Result | Evidence |
|-------|--------|----------|
| Unity SDK in app | **NOT FOUND** — no `unity_ads` / `UnityAds` package in `pubspec.yaml` | — |
| Unity via LevelPlay | **YES (dashboard-only)** | `lib/config/ad_config.dart:98-100` — `unityMediationNote`; `channel_tap_ad_rotator.dart:9-12` — comments state Unity is mediated inside LevelPlay, not a separate SDK |
| Code calls Unity APIs | **NOT FOUND** | Grep: no `UnityAds` class usage in `lib/` |

### 3.3 Adsterra

| Check | Result | Evidence |
|-------|--------|----------|
| WebView (visible) | **`webview_flutter`** — `AdsterraWebView` | `lib/ads/adsterra/adsterra_webview.dart:74-99` |
| Headless rotation | **`flutter_inappwebview`** — `HeadlessInAppWebView` | `lib/ads/background_ad_engine.dart:164+` |
| Direct link / browser | `url_launcher` + `external_url_launcher` MethodChannel | `lib/ads/adsterra/adsterra_direct_link.dart`, manifest queries |
| Placements (sample) | HOME/Sports/Live/News natives & 728 banners; global social bar; 1×1 popunder host | `tv_screen.dart`, `other_screens.dart`, `news_screen.dart`, `main.dart:394-400` |
| Placeholder URLs in source | **Debug-only** (release blocked) | `_debugPlaceholderDirectLinks` / `_debugPlaceholderSmartlinks` in `ad_config.dart`; `AdConfig.assertReleaseMonetization()` in `main.dart` throws if placeholders or no monetization config in release |

### 3.4 Monetag (PropellerAds-family)

| Check | Result | Evidence |
|-------|--------|----------|
| Config | **`MonetagConfig`** — **dart-define / `secrets.json` only** (no hardcoded zone IDs in `lib/`) | `lib/config/monetag_config.dart` |
| Ship zones (local) | onclick **11062342**, vignette **11062367**, push **11062382**, in-page **11062385**, direct **11062386** | `secrets.json` (not committed) |
| Script hosts | `MONETAG_ONCLICK_HOST` = `https://al5sm.com` (app appends `/tag.min.js`); vignette `https://n6wxm.com`; in-page `https://nap5k.com` | `propeller_html.dart` |
| Engine | **`PropellerEngine`** — smartlink, vignette dialog | `lib/ads/propeller/propeller_engine.dart` |
| HTML injection | **`PropellerHtml`** — `dataset.zone` script tags | `lib/ads/propeller/propeller_html.dart` |
| Channel-tap rotation | Monetag smartlink slot in rotator | `channel_tap_ad_rotator.dart:18-20` |
| Player sticky | Zone **11062385** (in-page push) | `ad_config.dart:268-269`, `player_screen.dart` Propeller widget |

### 3.5 Tri-network orchestration

```14:15:lib/ads/ad_waterfall.dart
/// Tri-network waterfall: LevelPlay (IronSource + Unity mediation) → Adsterra WebView.
class AdWaterfall {
```

- **Global orchestrator:** `lib/ads/ad_manager.dart` (564 LOC) — init, channel tap, exit intent, background engine schedule.
- **Channel tap:** `lib/ads/strategies/channel_tap_ad_rotator.dart` — LevelPlay interstitial slots A/B, Monetag smartlink, Adsterra browser/direct.
- **Waterfall timeout:** 3s per network (`ad_config.dart:247-248`).

### 3.6 Frequency caps

| Layer | File | Mechanism |
|-------|------|-----------|
| Session funnel | `lib/services/ad_trigger_manager.dart` | Interstitial cooldown 90s, max 8/session, channel clicks before interstitial = 3 (`ad_config.dart:241-244`) |
| Hourly/device | `ad_config.dart:229-237` | e.g. interstitial max 8/hour, rewarded 5/hour |
| Adsterra popunder | `AdTriggerManager` + `adsterraPopunderMaxPerSession = 2` | `ad_config.dart:236-237` |
| Network isolation | 30s after Adsterra before LevelPlay | `ad_config.dart:238-239` |
| Server caps | `lib/services/server_cap.dart` | GET `{CAP_BASE_URL}/caps/{installId}`; **release blocks all ads** if URL empty and not `CAP_LOCAL_ONLY_MODE` / `LUMIO_SIDELOAD_DEV` (`blocksAdsInRelease`) |
| WebView concurrency | `lib/ads/utils/webview_pool.dart` | Default max **3**; overridable via Firebase RC `webview_pool_max_concurrent`; `applyMemoryPressure()` halves under RAM pressure |

### 3.7 Device ID / shared WiFi mitigation

| Feature | Status | Evidence |
|---------|--------|----------|
| Install ID (encrypted store) | **YES** | `lib/services/secure_install_id_store.dart`, `ad_safety_service.dart:92-123` |
| Device fingerprint | **YES** | SHA-256 of installId + device signals (`ad_safety_service.dart:158-166`) |
| Cap API keyed by installId | **YES** | `server_cap.dart:89-96` |
| VPN / geo routing | **Partial** | `vpn_signal_service.dart` — `preferCleanSdkRouting` biases to LevelPlay |

### 3.8 GDPR / consent

| Check | Status | Evidence |
|-------|--------|----------|
| First-launch dialog | **YES (minimal)** | `lib/widgets/ad_consent_dialog.dart` |
| LevelPlay privacy flags | **YES** | `lib/services/ad_consent_service.dart:65-67` — `LevelPlay.setConsent` via mediation SDK |
| IAB TCF / licensed CMP | **Partial** | `IabConsentBridge` stores TC string (`lumio_iab_tc_string_v1`); no licensed CMP SDK yet — UMP-ready scaffold |
| CCPA explicit opt-out copy | **Partial** | `ads_privacy_screen.dart` — “opt out of sale” text for limited ads |
| WebView cookie consent | **NOT FOUND** | Ad WebViews load third-party scripts without separate WebView CMP |

### 3.9 Test vs production

| Toggle | Mechanism |
|--------|-----------|
| Debug ads off by default | `AdConfig.blockAdsInThisBuild` — requires `ADS_ENABLED=true` (`ad_config.dart:58-60`) |
| Release always allows ad init | `adsEnabled => kReleaseMode \|\| ...` (`ad_config.dart:52-53`) |
| Diagnostics | `DIAGNOSTICS_ENABLED` → `DevDiagnosticsScreen`, `ZoneValidator` |
| LevelPlay test mode in Dart | **NOT FOUND** as separate flag — relies on dashboard test devices |

### 3.10 Estimated impressions per session (**ESTIMATE**)

Assumptions: 8–12 min session, ads enabled, South Asia traffic, aggressive mode sometimes on.

| Surface | Est. count/session |
|---------|-------------------|
| LevelPlay banner (HOME, auto-refresh ~60s dashboard) | 8–15 impressions |
| Adsterra list natives (every 4–8 rows, 3 tabs browsed) | 6–12 |
| Adsterra 728 / social bar | 4–8 |
| Channel-tap funnel (interstitial OR Monetag OR direct every 3rd tap) | 2–4 full-screen events |
| Background headless Adsterra (cap 40/session, 60s rotation) | 0–8 (often throttled) |
| Popunder (session cap 2) | 0–2 |
| Player mid-roll / Monetag in-page | 0–2 |
| **Total ad events (blended)** | **~25–45** (not all billable; fill-dependent) |

**Revenue cap RIGHT NOW:** fill rates on sideload + WebView policy risk + no licensed CMP (TCF storage only) + Monetag default zones if CI overrides missing.

### 3.11 Background & aggressive layers (Adsterra + Monetag)

| Component | Role | Evidence |
|-----------|------|----------|
| `BackgroundAdEngine` | Headless 1×1 Adsterra URL rotation (60s, session cap 40) | `lib/ads/background_ad_engine.dart`, `ad_config.dart:254-256` |
| `AdsterraPopunderHost` | 1×1 shell overlay host | `lib/main.dart:394-400` |
| `GlobalSocialBarHost` | Sticky Adsterra social WebView all tabs | `lib/ads/widgets/global_social_bar.dart`, `ad_placement_config.dart:56-57` |
| `PushSubscriptionService` | First-home Monetag push subscription WebView prompt | `lib/services/push_subscription_service.dart`, `ad_config.dart:262-265` |
| `exit_intent_handler.dart` | Back-press: popunder → video overlay → waterfall interstitial | Multi-step exit funnel |
| `geo_targeting.dart` | Geo / routing hints for ad strategies | `lib/ads/strategies/geo_targeting.dart` |

### 3.12 Private Adsterra telemetry (not Firebase)

| Item | Detail |
|------|--------|
| Client | `HttpAdsterraTelemetryClient` — HMAC-signed POST | `lib/ads/adsterra_telemetry_client.dart` |
| Config | `ADSTERRA_TELEMETRY_URL` + `ADSTERRA_TELEMETRY_HMAC_KEY` | `ad_config.dart:217-221` |
| Debug | `logAdsterraTelemetry` → logcat + optional POST | `lib/utils/ad_debug_log.dart` |
| Zone validation events | `lumio_zone_validation` via `ZoneValidator` (diagnostics) | `lib/ads/diagnostics/zone_validator.dart` |
| Ad fill analytics (Firebase) | `ad_waterfall_attempt`, `ad_impression` | `lib/ads/analytics/ad_fill_analytics.dart`, `docs/AD_DASHBOARD_QUERIES.md` |

### 3.13 Firebase Remote Config (ad kill switches)

| Key area | Service | Evidence |
|----------|---------|----------|
| Ads master switch | `AdSafetyService.adsEnabledRemote` | `ad_safety_service.dart` — Remote Config prefetch in `ensureReady` |
| LevelPlay enable | `levelPlayEnabledRemote` | Same |
| Aggressive density | `aggressiveMode` | Drives native interval, player mid-roll — `ad_placement_config.dart:15-16` |
| Firebase off switch | `FIREBASE_ENABLED` dart-define | `firebase_bootstrap.dart:9-11` |

### 3.14 Rewarded use cases (LevelPlay)

| Feature | Placement / trigger | File |
|---------|---------------------|------|
| HD unlock | Player / settings flows | `ad_manager.dart` rewarded paths |
| VIP ad-free window | Rewarded → `UserPreferences.adFreeUntil` | `ad_config.dart:318`, `ad_trigger_manager.dart` |
| Coins | `AdConfig.coinsPerRewardedAd` | `ad_manager.dart:524-528` |
| Spin wheel | `RewardedFeatures.spinWheel` | `rewarded_gate.dart`, `spin_wheel_screen.dart` |

---

## SECTION 4 — Live Streaming Module (CRITICAL for World Cup)

| Item | Detail |
|------|--------|
| **Library** | **`media_kit`** + `media_kit_video` + Android native libs | `pubspec.yaml:27-29`, `player_screen.dart:11-12, 206` |
| **Underlying player** | libmpv (via media_kit) — **not** ExoPlayer directly in Dart | — |
| **Stream types** | Primarily **HLS** (`.m3u8`); some HTTP origins | GitHub playlist `allchannelking.m3u8` (~700+ channels) |
| **Buffering / retry** | **YES** — `_bufferingTimeout` 12s, `_maxFailoverAttempts = 3` | `player_screen.dart:147-152` |
| **Quality switching** | **Partial** — `hls_quality_service.dart` exists; UX varies by source |
| **Origin** | **Mixed CDN + direct IPs** — cleartext allowlist for legacy hosts | `network_security_config.xml` + `tool/gen_network_security_config.py` |
| **HTTP in `app_provider.dart`** | **~2** references (not embedded catalog) | Catalog URLs live in remote M3U only |
| **Latency** | **ESTIMATE 4–15s** start (HLS + HTTP origins + token round-trip) | — |
| **Concurrent viewers** | **NOT VISIBLE** in client — no backend viewer count | — |
| **DRM** | **NOT FOUND** (Widevine) | — |
| **Token protection** | **Stronger client-side** | `StreamTokenService` — **pinned Dio** (`SecureDio.createForBaseUrl`), **3× retry**, 8s timeout; `ChannelResolver`; requires live `STREAM_TOKEN_BASE_URL` |
| **Credentialed URLs in source** | **0** `user:pass@` in `lib/` | Grep clean |
| **Stability rating** | **5/10** | Strong player logic undermined by HTTP origins, cleartext hosts, token backend not guaranteed in ops |
| **Cloudflare as stream/CDN host** | **Partial** | At least one HLS on `*.pages.dev`; channel list Worker — Section 13 |

### 4.1 Data sources (channel catalog pipeline) — **rev.5**

| Source | Priority | Evidence |
|--------|----------|----------|
| **GitHub M3U (single source)** | **Only** | `SpecialLinkConfig.primaryPlaylistPageUrl` → `kakonzone/allchannelking.m3u8` |
| Loader | `GitunPlaylistService.loadChannels` → raw GitHub URL | `lib/services/special_link/gitun_playlist_service.dart` |
| Facade | `CatalogService.loadCatalog` | `lib/services/catalog_service.dart` |
| UI state | `AppProvider.loadChannels(forceRefresh:)` | `lib/provider/app_provider.dart` (~939 LOC) |
| Cache | **1 hour** TTL; pull-to-refresh bypasses | `SpecialLinkConfig.gitunCacheTtl` |
| Channel IDs | Prefix `ack` per Gitun row | `gitun_playlist_service.dart` |
| **Removed from ship path** | — | Embedded `_hardcodedChannels`; bundled `user_playlist.m3u` / `scanned_iptv.m3u`; CricHD; in-app paste lists; Worker merge in `AppProvider` |
| `RemoteChannelsService` | **Code remains**; **not** called by catalog | `REMOTE_CHANNELS_URL` still in `secrets.json` for future/ops |
| Stream token API | Optional signing | `StreamTokenService` — `STREAM_TOKEN_BASE_URL` |
| Stream health scan | After catalog load | `stream_health_service.dart` |

**Ops:** Update channels by pushing to GitHub repo; app picks up within TTL or on user refresh (not instant).

### 4.2 Scores / matches (adjacent to LIVE)

| Item | Detail |
|------|--------|
| **Service** | `score_service.dart`, `live_events_service.dart`, **`match_channel_matcher.dart`**, **`footystream_service.dart`** |
| **FootyStream** | HTML scrape `footystream.pk/pk` + `/today` — teams, logos, kickoff; merged with ESPN/Cricbuzz |
| **Merge** | `ScheduleMerge` — same fixture (teams + day) → one card |
| **Background refresh** | `workmanager` periodic score task | `background_service.dart` |
| **UI** | Home “All Live Events”; Today tab; Sports grid |

### 4.3 Match ↔ channel matcher (`MatchChannelMatcher`)

**File:** `lib/services/match_channel_matcher.dart` (**~876 LOC**).

| Component | Purpose |
|-----------|---------|
| **`channelPoolFor`** | Filters catalog to Sports + regional categories (Bangladesh / Pakistan / India / English) from team names in fixture |
| **`findRelated`** | Scores each channel 0–200+; returns top **16** by score |
| **Team aliases** | 40+ nations/clubs — fixes BD/PK/IN + football nations (BR/AR/FR/DE/ES/PT) |
| **Tournament map** | IPL, BPL, FIFA WC, UCL, EPL, etc. → preferred broadcaster keywords |
| **Player boosts** | Shakib/Tamim → T Sports/Toffee; Messi/Ronaldo → beIN/Fox |
| **Scoring rules** | (1) Fixture-named channel `Team A vs Team B` +200; (2) numbered feeds BFL/EPL Live N +65; (3) broadcaster hint from API `match.channel`; (4) tournament mapping; (5) sport-specific cricket/football; (6) BD cross-category Nagorik/Toffee bonus |
| **Root-cause fixes** | `match.channel` = broadcaster not tournament; Nagorik in “Bangladesh” not “Sports” |

**Consumer:** `LiveEventsService` → Home live-event dialog — **all matched links unlocked** (instant play).

---

## SECTION 5 — Security Audit

### 5.1 Secrets in source

| Item | Finding |
|------|---------|
| LevelPlay / Adsterra keys | **Not hardcoded** — `String.fromEnvironment` in `ad_config.dart` |
| Monetag zone IDs | **Default zone numbers + script hosts in source** | `monetag_config.dart:7-44` — override via dart-define in prod |
| Toffee token | Env-only `TOFFEE_SUBSCRIBER_TOKEN` | `ad_config.dart:63-64` |
| `google-services.json` | **Gitignored** | `.gitignore:48` |
| `key.properties` / keystores | **Gitignored** | `.gitignore:64-66` |

### 5.2 Transport

| Item | Finding |
|------|---------|
| App cleartext default | **Disabled** | `AndroidManifest.xml:44`, `network_security_config.xml:4-8` |
| Legacy cleartext allowlist | **6 IP/host entries** | `network_security_config.xml:26-34` |
| `http://` in Dart | **136+ matches** across 6 lib files (mostly catalog) | `app_provider.dart` dominant |

### 5.3 Build hardening

| Item | Finding |
|------|---------|
| R8 minify + shrink | **YES (release)** | `build.gradle.kts:152-156` |
| Flutter obfuscate | **Optional** via `tool/build_release_apk.sh` | docs |
| Release signing | **Fail-closed** without `key.properties` | `build.gradle.kts:126-139` |

### 5.4 SSL pinning

| Item | Finding |
|------|---------|
| Implementation | **YES** — `SslPinning` + `SecureDio` (singleton + `createForBaseUrl`) | `lib/security/ssl_pinning.dart`, `lib/network/secure_dio.dart` |
| Release fail-fast | **YES** — pins + stream token URL + monetization config | `main.dart`: `SslPinning.assertReleaseConfiguration()`, `AdConfig.assertReleaseMonetization()` |
| Debug | Pinning **skipped** | `ssl_pinning.dart` — non-release returns true |

### 5.5 Runtime integrity

| Check | Status | Evidence |
|-------|--------|----------|
| Root / emulator / debugger / Frida / Xposed | **YES** | `security_manager.dart:88-100` |
| VPN block | **Off by default** | `security_config.dart:19` — `blockVpn = false` |
| APK signature check | **Optional** (empty hash = skip) | `security_config.dart:32` |
| Play Integrity | **Gated (optional)** | `PlayIntegrityService` — active when `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER` set; native bridge pending v1.1 (`docs/PLAY_INTEGRITY_OPTION_B.md`) |

### 5.6 Storage

| Item | Finding |
|------|---------|
| Install ID | **Encrypted** path available | `secure_install_id_store.dart` |
| Consent / caps / counters | **Plain SharedPreferences** | `ad_consent_service.dart`, `ad_trigger_manager.dart` |

### 5.7 WebView

| Item | Finding |
|------|---------|
| JS mode | **Unrestricted** for ad HTML | `adsterra_webview.dart:75` |
| JS bridges to native | **NOT FOUND** | No `JavascriptChannel` / `@JavascriptInterface` |
| Navigation filter | **Partial** — blocks `intent://`, `.apk` (non-adsterra) | `adsterra_webview.dart:84-91` |

### 5.8 Permissions

Declared: `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `AD_ID`, `POST_NOTIFICATIONS`, media foreground service, `WAKE_LOCK` — **reasonable for streaming + ads**; no `READ_CONTACTS` / `SMS`. **Not over-requested** for stated features.

### 5.9 Risk score: **HIGH**

| # | Vulnerability | Severity |
|---|---------------|----------|
| 1 | Monetag default zones + hosts committed — zone hijack / policy if not overridden in release | High |
| 2 | 76+ HTTP stream URLs + cleartext network config — MITM on playback | High |
| 3 | Ad WebViews with unrestricted JS + third-party ad scripts — WebView supply-chain | High |
| 4 | No licensed CMP — TC string storage only | High (business) |
| 5 | Sideload + aggressive ad UX — store/network ban risk | Medium–High |

---

## SECTION 6 — Performance & UX

| Item | Finding |
|------|---------|
| **APK download (release)** | **Target 25–38 MB** per ABI — `tool/build_release_apk.sh`, `tool/build_size_apk.sh` (`--split-per-abi`, arm64 default, obfuscate, tree-shake-icons) |
| **Installed on device** | **Target ~60–80 MB** — APK + native libs + **`AppStorageGuard`** soft 50 MB / hard 80 MB cache budget |
| **32-bit / Android 5–7** | **Optional** `BUILD_LEGACY_ABI=true` → `armeabi-v7a` + `arm64-v8a` APKs |
| Debug APK | **~234 MB** on disk (`app-debug.apk`) — not ship artifact |
| Cold start | **Improved** — short splash branding; ads deferred `warmupAfterHomeVisible()`; fast catalog `loadChannels(fullCatalog: false)` + background merge |
| **Low-RAM tuning** | **`PerformanceTuning`** (`lib/core/performance_tuning.dart`) — RAM tier from `MainActivity.getDeviceProfile`; adjusts ImageCache, disk logo cache, `ListView.cacheExtent`, `media_kit` buffer (2–4 MB) |
| Image cache | **`cached_network_image`** + bounded `lumioImageCache` (tier-aware object count) |
| Lists | Home/Browse use **`addRepaintBoundaries`**, reduced `cacheExtent` on low tier |
| Storage guard | **`AppStorageGuard`** — trims WebView + image cache on resume / 6h; low tier soft budget 40 MB |
| Memory leaks | **Risk** — `Player` / WebView / timers; `player_screen.dart` dispose paths present |
| ANR risk | **Medium–lower** — deferred notifications/audio/deep link; stream health not blocking live-event taps |
| Dark mode | **YES** — `AppProvider.toggleTheme`, `AppTheme` |
| Accessibility | **Weak–partial** — `Semantics` on consent dialog; no full pass; English/Bangla mix in strings |
| **Docs** | `docs/ANDROID_SIZE_AND_PERFORMANCE.md` |

---

## SECTION 7 — Tier-1 Traffic Readiness (UK / US)

| Requirement | Status |
|-------------|--------|
| i18n | **Scaffold** — `l10n.yaml`, `lib/l10n/app_en.arb`, `flutter: generate: true` in `pubspec.yaml`; not wired to UI yet |
| Privacy Policy in-app | **YES** — `LegalConfig` + `AdsPrivacyScreen` (`lib/config/legal_config.dart`) |
| GDPR banner | **Partial** — custom dialog only, not TCF |
| CCPA opt-out | **Partial** — limited-ads copy, not full CCPA flow |
| WebView tracking consent | **NOT FOUND** |
| app-ads.txt on domain | **Template in repo** — `legal/app-ads.txt`; hosting on `lumio.app` not verified |
| IAB TCF v2.2 | **Partial** — `IabConsentBridge` TC string persistence; no CMP SDK |
| Live chat moderation | **NOT APPLICABLE** — no live chat |
| Region-based ad routing | **Partial** — VPN/geo prefers LevelPlay (`AdSafetyService`) |
| Currency / timezone | **Partial** — `bdt_time.dart`; no full locale |

**Tier-1 readiness: 4/10** (improved scaffold; still no licensed CMP or hosted app-ads.txt)

---

## SECTION 8 — User Acquisition Infrastructure

| Feature | Status | Evidence |
|---------|--------|----------|
| Referral system | **Scaffold** | `lib/services/referral_service.dart` — code capture + prefs; server redeem when `LUMIO_BACKEND_*` set |
| Deep linking | **YES** — `lumio://open`, `lumio://channel`, `https://lumio.app/open` | `AndroidManifest.xml:62-83`, `deep_link_service.dart` |
| Firebase Dynamic Links | **NOT FOUND** | — |
| Share-to-social | **Partial** — drawer “Share app” copies campaign link | `share_campaign_service.dart` |
| Push (FCM) | **YES** | `firebase_messaging`, `notification_service.dart` |
| In-app update | **YES** | `app_update_service.dart` + `APP_UPDATE_MANIFEST_URL` |
| Analytics | **Firebase Analytics** | `ad_analytics.dart`, `attribution_service.dart` |
| Attribution | **YES** — UTM on deep links, Firebase events | `attribution_service.dart` |
| Amplitude / Mixpanel | **NOT FOUND** in dependencies | — |
| **Workmanager** background tasks | **YES** — scores, live match poll | `lib/services/background_service.dart` |
| **Coin / streak engagement** | **YES** — not UA, retention | `coin_economy.dart`, `streak_service.dart` |
| **World Cup smoke doc** | **YES** | `docs/WORLD_CUP_RELEASE_SMOKE_TEST.md`, `tool/smoke_test_device.sh` |

### 8.1 Payment & payout (owner context: Payoneer + crypto)

| Rail | In-app integration | Evidence |
|------|-------------------|----------|
| Payoneer | **NOT FOUND** | No Payoneer SDK, API, or UI in `lib/` |
| USDT / BTC / crypto wallet | **NOT FOUND** | No Web3, wallet connect, or crypto payout UI |
| Google Play Billing | **NOT APPLICABLE** | Sideload only |
| In-app purchase package | **NOT FOUND** | Analytics maps `'in_app_purchase'` event name only — `ad_analytics.dart:36` (not a billing SDK) |
| “Remove ads” | **Local preference / rewarded VIP timer** — not a paid SKU | `UserPreferences.removeAdsPurchased`, `adFreeUntil` |

Publisher payouts (Payoneer/crypto) are **off-app** (ad network dashboards). The app does not implement user-facing payments.

---

## SECTION 9 — Revenue Projection Based on Current State

**Assumptions:** 25–35 monetized events/session, 55% fill, blended eCPM **$0.80** (BD/IN/PK) / **$4.00** (UK/US small slice).

| Metric | BD/IN/PK-heavy | With 10% UK/US |
|--------|----------------|----------------|
| Ads/session (billable, est.) | 14–20 | 16–22 |
| ARPDAU (est.) | **$0.011 – $0.018** | **$0.015 – $0.025** |

| DAU | Monthly revenue (est.) |
|-----|------------------------|
| 5,000 | **$1,650 – $2,750** |
| 25,000 | **$8,250 – $13,750** |
| 100,000 | **$33,000 – $55,000** |

**Bottlenecks capping revenue today:**
1. Sideload trust + aggressive first-tap ads → lower retention vs TV competitors  
2. WebView / Monetag / Adsterra fill variability on low-end devices  
3. `WebViewPool` max 3 → deferred impressions on scroll-heavy sessions  
4. Monetag default zones if CI overrides missing  
5. No licensed CMP → cannot safely scale paid UA to UK/US  

---

## SECTION 10 — Gap Analysis (Critical Missing Pieces)

### P0 (blockers — must fix before launch)

| # | Item | Code | Ops |
|---|------|------|-----|
| 1 | Stream token API live | **Done** — pinned Dio + 3× retry | Deploy backend + `STREAM_TOKEN_BASE_URL` |
| 2 | SSL pins in release | **Done** (`SslPinning`) | Set `SSL_PIN_*` dart-defines |
| 3 | Legal pages live | **Done** — HTML in `legal/` + `LegalConfig` | Host HTML at `lumio.app` |
| 4 | No placeholder Adsterra in release | **Done** — `assertReleaseMonetization()` | Set all `ADSTERRA_*` / `MONETAG_*` in CI |
| 5 | Secrets audit | **Done** — `scripts/audit_secrets.sh` → `SECRETS_REPORT.md` | Rotate if findings; run gitleaks in CI |
| 6 | 4-network device validation | **ZoneValidator** (diagnostics) | Real-device fill test per `docs/AD_ZONE_INVENTORY.md` |

See `docs/PHASE10_CLOSEOUT.md`, `FIX_REPORT.md`.

### P1 (high impact — within 1 week)

| # | Item | Code status | Ops / follow-up |
|---|------|-------------|-----------------|
| 6 | HTTP→HTTPS hygiene | **Script** — `scripts/fix_http_streams.sh` | Migrate top World Cup HTTP streams; shrink NSC allowlist |
| 7 | IAB TCF | **Partial** — `IabConsentBridge` | Licensed CMP or UMP when ready for UK/US |
| 8 | Remote channels Worker | **Done** — `REMOTE_CHANNELS_URL`, SecureDio, ETag | Optional Worker host pins |
| 9–10 | God-file split | **Partial** — `player_screen_widgets.dart`, split providers | `player_screen` ~3181 LOC; `app_provider` ~3456 LOC remain |
| 11 | Ad fill analytics | **Done** — `ad_fill_analytics.dart`, BigQuery doc | Wire waterfall calls if not already via `AdAnalytics` |

### P2 (post-launch)

| # | Item | Code status | Ops / follow-up |
|---|------|-------------|-----------------|
| 12 | Wallet API | **Scaffold** — `wallet_api_client.dart` | Deploy `docs/BACKEND_WALLET_API.md` endpoints |
| 13 | Referral | **Scaffold** — `referral_service.dart` | Server redeem + rewards |
| 14 | i18n | **Scaffold** — ARB + `l10n.yaml` | BN/HI/UR strings + UI wiring |
| 15 | Accessibility | **Partial** — consent `Semantics` | Full screen reader pass |
| 16 | app-ads.txt | **Done** in repo — `legal/app-ads.txt` | Host at `https://lumio.app/app-ads.txt` |
| 17 | Play Integrity | **Gated** — `play_integrity_service.dart` | Set `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER` + native bridge v1.1 |
| 18 | WebView pool RC | **Done** — RC key + memory pressure | Set `webview_pool_max_concurrent` in Firebase RC |

### Phase 10 (reference)

| Task | Client | Ops |
|------|--------|-----|
| Stream token | Done | Deploy API |
| SSL pins | Done | Set defines |
| Legal | Done | Host pages |
| Secrets audit | Scripts | Run + rotate |
| Zone validator | Done | Device test |

Details: `docs/PHASE10_CLOSEOUT.md`, `docs/PHASE10_TASK_[1-5]_VERIFICATION.md`.

---

## SECTION 11 — Code Quality Issues

| Issue | Evidence |
|-------|----------|
| Hardcoded strings | Extensive UI copy; mixed EN/BN |
| Magic numbers | Ad caps in `ad_config.dart`; player timeouts in `player_screen.dart` |
| Duplicated widgets | Multiple ad host wrappers; list tile patterns |
| God classes | `player_screen.dart` **3181** LOC (+ **366** in `player_screen_widgets.dart`); `app_provider.dart` **3456** LOC; `ad_manager.dart` **564** LOC |
| Null safety | Dart 3 — **OK** |
| Async misuse | Heavy `unawaited` — race risk under load |
| setState depth | Large screens (`player_screen`, `tv_screen`) |

---

## SECTION 12 — Final Verdict

| Metric | Score |
|--------|-------|
| **Launch readiness** | **84%** |
| **World Cup readiness** | **78%** |
| **Tier-1 traffic readiness** | **32%** |
| **Estimated days to production** | **5–10 days** (ops: token API deploy, pins in CI, legal hosting, device soak, HTTP migration) |

### Top 10 action items (execution order)

1. Deploy stream token backend; verify `[StreamToken] fetched for …` on protected channels.  
2. Set all `SSL_PIN_*` in release CI; confirm `[SSL] pin verified` in logcat.  
3. Host privacy / terms / data-deletion; verify taps from consent + settings.  
4. Override **all** Monetag + Adsterra dart-defines in release (release build fails on placeholders).  
5. Device soak: LevelPlay + Adsterra + Monetag + background engine (`DIAGNOSTICS_ENABLED`).  
6. HTTPS-first for top 20 World Cup channels; remove cleartext hosts from NSC.  
7. Crashlytics watch player failover during load test.  
8. Campaign links: `lumio://open?source=facebook&campaign=wc2026`.  
9. Tune Remote Config `aggressive_mode` vs retention during peak.  
10. Do not buy UK/US UA until TCF/CMP + app-ads.txt live.  

---

## Four-network ads summary (IronSource · Unity · Adsterra · Monetag)

```
┌─────────────────────────────────────────────────────────────────┐
│                        AdManager (singleton)                     │
├─────────────┬──────────────┬────────────────┬───────────────────┤
│ LevelPlay   │ Unity Ads    │ Adsterra       │ Monetag           │
│ (SDK 9.2.0) │ (mediation   │ WebView +      │ PropellerEngine   │
│             │  ONLY)       │ direct +       │ zones 11062342+   │
│             │              │ headless       │                   │
├─────────────┴──────────────┴────────────────┴───────────────────┤
│ AdWaterfall: LP interstitial/rewarded → Adsterra fullscreen → link │
│ Channel tap rotator: Monetag smartlink | LP x2 | Adsterra browser  │
│ Caps: AdTriggerManager + ServerCap + WebViewPool(3)                │
└─────────────────────────────────────────────────────────────────┘
```

| Network | In-app SDK? | Primary surfaces | Config surface |
|---------|-------------|------------------|----------------|
| IronSource LevelPlay | **Yes** | Banner, interstitial, rewarded | `LEVELPLAY_*` dart-define |
| Unity Ads | **No** (mediated) | Fills via LevelPlay auction | LevelPlay dashboard |
| Adsterra | **WebView + browser** | Natives, 728, social, popunder, background | `ADSTERRA_*` dart-define |
| Monetag | **Script/WebView/link** | Onclick, vignette, in-page push, direct | `MONETAG_*` dart-define + defaults in `monetag_config.dart` |

---

## SECTION 13 — Cloudflare Usage Audit

**Verdict:** Lumio **uses Cloudflare indirectly at runtime** (Workers + Pages URLs in catalog/API). There is **no Cloudflare SDK**, **no `wrangler.toml`**, and **no Worker source code** in this repo — only docs + hardcoded endpoints.

### 13.1 Runtime (app calls Cloudflare-hosted endpoints)

| Use | Status | URL / location | Evidence |
|-----|--------|----------------|----------|
| **Channel catalog API** | **ACTIVE** (dart-define default) | `REMOTE_CHANNELS_URL` → default `https://lumio-channels.kakonzone.workers.dev/channels` | `lib/config/app_config.dart`, `remote_channels_service.dart` |
| Catalog merge logic | If Worker returns 200 + JSON array → **replaces** bundled `_hardcodedChannels`; else fallback to embedded list | `lib/provider/app_provider.dart:435-437` |
| Cache | 30 min in-memory TTL + **ETag** (`If-None-Match` / 304) | `remote_channels_service.dart` |
| Transport | **SecureDio** GET, 3× retry, 10s timeout | `remote_channels_service.dart` — same pin model as stream token host when pins configured |
| **HLS stream origin (Pages)** | **In embedded catalog** | `https://starsportshindiii.pages.dev/index.m3u8` | `lib/provider/app_provider.dart:1048` |
| Third-party Worker stream (playlist) | **Present in assets, not Lumio-owned** | `https://playboxtv.developed-for-pishow.workers.dev/wanda.m3u8` | `assets/data/user_playlist.m3u:757`, `tool/user_paste_urls.txt:354` |

```dart
// lib/services/remote_channels_service.dart:13-14
static const _channelsUrl =
    'https://lumio-channels.kakonzone.workers.dev/channels';
```

```dart
// lib/provider/app_provider.dart:435-437
final remoteChannels = await RemoteChannelsService.fetch();
final baseChannels =
    remoteChannels.isNotEmpty ? remoteChannels : _hardcodedChannels;
```

### 13.2 Planned / documented (not proven live from repo)

| Item | Status | Evidence |
|------|--------|----------|
| `lumio.app` marketing + deep links | **In-app** (`https://lumio.app/open`) | `AndroidManifest.xml:79-82`, `deep_link_service.dart:57` |
| Legal / APK hosting on Cloudflare | **Docs only** — Cloudflare Pages + DNS steps | `docs/LEGAL_HOSTING.md:5-9`, `docs/LEGAL_PAGES_HOSTING.md` |
| Stream token API on `api.lumio.app` | **Planned** in build docs; **not** a Cloudflare Worker in client code | `docs/BUILD.md`, `docs/BACKEND_STREAM_TOKEN_CONTRACT.md` |
| Token/signing **Worker sketch** | **Example JS only** in docs (not deployed here) | `docs/STREAM_PROXY_SETUP.md:43-56` |

### 13.3 NOT FOUND in repository

| Item | Result |
|------|--------|
| `wrangler.toml` / Workers project in repo | **NOT FOUND** |
| Cloudflare Flutter/Dart SDK | **NOT FOUND** |
| Cloudflare R2 / D1 / KV bindings | **NOT FOUND** |
| `SSL_PIN_*` for `*.workers.dev` or `*.pages.dev` | **Optional** — Worker uses `SecureDio`; add host-specific pins in CI if required |
| `network_security_config.xml` Cloudflare-specific domains | **NOT FOUND** — `*.workers.dev` / `*.pages.dev` rely on default HTTPS trust |

### 13.4 Cloudflare WARP / VPN detection (not infrastructure)

The app **detects** Cloudflare’s 1.1.1.1 / WARP app as a VPN signal for ad routing — it does **not** mean Lumio runs on Cloudflare.

| Signal | Evidence |
|--------|----------|
| ASN blocklist | `13335`, `209242` — Cloudflare WARP / CF | `lib/services/fraud/vpn_asn_catalog.dart:24-25` |
| Package denylist | `com.cloudflare.onedotonedotonedotone` | `vpn_asn_catalog.dart:79`, `VpnDetectionBridge.kt:57` |

Effect: users on **Cloudflare WARP** may get `preferCleanSdkRouting` → more LevelPlay, less Adsterra (`AdSafetyService`).

### 13.5 World Cup / ops implications

1. **Single point of failure:** If `lumio-channels.kakonzone.workers.dev` is down, app silently uses `_hardcodedChannels` (no user-facing error) — good fallback, stale catalog risk.  
2. **Worker URL configurable** — `REMOTE_CHANNELS_URL` dart-define (default unchanged).  
3. **Third-party `*.workers.dev` / `*.pages.dev` streams** in playlist/catalog — availability and ToS are outside your Cloudflare account.  
4. **Pin gap (reduced):** Catalog fetch uses pinned Dio; explicit `*.workers.dev` SPKI pins still recommended for release.  
5. **Recommended ops:** Host `lumio.app`, `app-ads.txt`, legal pages, and optionally `api.lumio.app` on Cloudflare (Pages + Workers + DNS) per docs — **confirm in Cloudflare dashboard** (not verifiable from APK alone).

### 13.6 Cloudflare score

| Aspect | Score (1–10) | Note |
|--------|--------------|------|
| Integration maturity | **6** | `REMOTE_CHANNELS_URL` dart-define; ETag; no IaC in repo |
| Security (pins, config) | **6** | SecureDio catalog fetch; host pins optional |
| Operational readiness | **7** | Fallback + 304 refresh |
| **Overall Cloudflare footprint** | **Partial** | **Yes for channels API + some streams; no full CF stack in app** |

---

## SECTION 14 — Firebase & Remote Services

| Service | Package | Wired? | Evidence |
|---------|---------|--------|----------|
| Firebase Core | `firebase_core: 4.9.0` | **Optional** | `firebase_bootstrap.dart` — skips if no `google-services.json` |
| Crashlytics | `firebase_crashlytics: 5.2.2` | **When Core OK** | Player/stream errors, token failures |
| Analytics | `firebase_analytics: 12.4.1` | **Yes** | `ad_analytics.dart`, `attribution_service.dart`, `coin_economy.dart` |
| Remote Config | `firebase_remote_config: 6.5.1` | **Yes** | `AdSafetyService.prefetchRemoteConfig` |
| FCM push | `firebase_messaging: 16.2.2` | **Yes** | `notification_service.dart` |
| Local notifications | `flutter_local_notifications: 21.0.0` | **Yes** | Display layer for FCM |

| Backend (dart-define) | Purpose | Default |
|----------------------|---------|---------|
| `LUMIO_BACKEND_BASE_URL` | Toffee creds / security API | `__MISSING__` |
| `LUMIO_BACKEND_APP_KEY` | Backend auth header | `__MISSING__` |
| `STREAM_TOKEN_BASE_URL` | Signed streams | `__MISSING__` |
| `REMOTE_CHANNELS_URL` | Cloudflare Worker catalog | Default Workers URL in `app_config.dart` |
| `CAP_BASE_URL` + `CAP_HMAC_KEY` | Server ad caps | empty unless CI |
| `CAP_LOCAL_ONLY_MODE` | Skip server caps QA | `ad_config.dart:207-209` |

| Dev-only | Purpose |
|----------|---------|
| `bin/dev_server.dart` | Shelf server for local creds/caps testing | `pubspec.yaml:47` comment |

---

## SECTION 15 — Monetization Beyond Ads (Coins, Ad-Free)

| Feature | Status | Evidence |
|---------|--------|----------|
| Coin balance + ledger | **YES** | `lib/services/coin_economy.dart` — SharedPreferences |
| Daily login coins | **YES** | `AdConfig.dailyLoginCoins = 5`, `UserPreferences.grantDailyLoginBonus` |
| Streak bonuses | **YES** | `streak_service.dart` — 3/7/14/30 day coin grants |
| Spin wheel | **YES** | Rewarded ad gate + coin prizes |
| Ad-free via rewarded | **YES** | `adFreeMinutesAfterVip = 60` |
| Remove-ads flag | **Local pref only** — no Play billing | `UserPreferences.removeAdsPurchased` |
| Paywall / subscription SKU | **NOT FOUND** | — |

**Risk:** Coin economy is client-side — exploitable if not validated server-side (**NOT FOUND** server wallet API).

---

## SECTION 16 — Native Android, CI/CD, Release Pipeline

| Item | Detail |
|------|--------|
| **Kotlin bridges** | `MainActivity.kt` (deep link MethodChannel), `VpnDetectionBridge.kt` | `android/app/src/main/kotlin/com/kakonzone/lumio/` |
| **Native C++** | CMake under `android/app/src/main/cpp/` — linked in `build.gradle.kts:111-121` |
| **ProGuard** | `proguard-rules.pro` + R8 optimize release | `build.gradle.kts:154-156` |
| **Signing** | Release requires `key.properties` or env signing vars | `docs/RELEASE_SIGNING.md` |
| **Obfuscated release script** | `tool/build_release_apk.sh` — split ABI, tree-shake, `MAX_APK_MB=38`, optional `BUILD_LEGACY_ABI` | Enforces legal + stream token + LevelPlay + Adsterra |
| **Size QA script** | `tool/build_size_apk.sh` — sideload `CAP_LOCAL_ONLY_MODE` guard | `docs/ANDROID_SIZE_AND_PERFORMANCE.md` |
| **RAM profile bridge** | `MainActivity.getDeviceProfile` → Flutter `PerformanceTuning` | `totalRamMb`, `lowMemoryDevice` |
| **Debug run script** | `scripts/flutter_run_with_ads.sh` | `docs/BUILD.md` |
| **CI** | `flutter analyze --fatal-warnings` + `flutter test` | `.github/workflows/ci.yml:24-28` |
| **NDK** | Flutter default `28.2.13676358` | Flutter SDK `FlutterExtension.kt` |

---

## SECTION 17 — Key Dependencies (Production)

| Category | Packages | Notes |
|----------|----------|-------|
| Playback | `media_kit`, `media_kit_video`, `media_kit_libs_android_video` | Android-only native libs |
| Ads SDK | `unity_levelplay_mediation` | Unity via mediation only |
| WebView | `webview_flutter`, `flutter_inappwebview` | Visible ads vs headless engine |
| HTTP | `http`, `dio` | Stream token + remote channels use **pinned `SecureDio`**; legacy M3U fetch still uses `http` |
| State | `provider` | No Riverpod/Bloc |
| Images | `cached_network_image`, `shimmer`, `lottie` | |
| Security | `encrypt`, `crypto`, `androidx.security:security-crypto` (Gradle) | |
| Background | `workmanager` | Min 15 min periodic on Android |
| Firebase | core, analytics, messaging, remote_config, crashlytics | |

---

## SECTION 18 — Documentation & Ops Index

| Doc | Purpose |
|-----|---------|
| `docs/BUILD.md` | dart-define / secrets / release flags |
| `docs/SECRETS.md` | Env + `build_release_apk.sh` |
| `docs/WORLD_CUP_RELEASE_SMOKE_TEST.md` | Device QA matrix |
| `docs/PHASE10_CLOSEOUT.md` | P0 code vs ops |
| `docs/SSL_PINNING.md` | Pin extraction |
| `docs/BACKEND_STREAM_TOKEN_CONTRACT.md` | Token API |
| `docs/AD_ZONE_INVENTORY.md` | 4-network zones |
| `docs/CREDENTIAL_ROTATION.md` / `CREDENTIAL_ROTATION_URGENT.md` | Secret rotation |
| `docs/NETWORK_SECURITY_AUDIT.md` | Cleartext allowlist |
| `docs/ANDROID_SIZE_AND_PERFORMANCE.md` | APK 25–38 MB, install 60–80 MB, Android 5.0+, low-RAM |
| `docs/DEEP_LINK_ATTRIBUTION.md` | Campaign URLs |
| `docs/SIDELOAD_UPDATE.md` | APK update manifest |
| `docs/APP_ADS_TXT_TEMPLATE.md` | app-ads.txt |
| `docs/LEGAL_HOSTING.md` | Cloudflare Pages legal |
| `docs/STREAM_PROXY_SETUP.md` | Worker sketch |
| `docs/CRASHLYTICS_DASHBOARD.md` | Crash ops |
| `AUDIT_REPORT.md` | This document |
| `FIX_REPORT.md` | 18-item fix sprint status |
| `BACKEND_CHECKLIST.md` | Ops checklist (token, legal, Worker) |
| `NEW_DART_DEFINES.env` | CI define template |
| `SECRETS_REPORT.md` | Generated by `scripts/audit_secrets.sh` |
| `legal/README.md` | Host privacy/terms/data-deletion + app-ads.txt |
| `docs/BACKEND_WALLET_API.md` | Wallet API contract |
| `docs/AD_DASHBOARD_QUERIES.md` | BigQuery fill-rate queries |

---

## SECTION 19 — Payment Rails (Payoneer / USDT / BTC)

**Owner-stated goal:** Payoneer + crypto for publisher settlements.

| Question | Answer |
|----------|--------|
| Does the app process user payments? | **NO** |
| Does the app show Payoneer/crypto payout UI? | **NOT FOUND** |
| Where do ad revenues settle? | **Off-app** — IronSource, Adsterra, Monetag dashboards |
| In-app monetization | **Ads only** + optional rewarded engagement (coins, ad-free minutes) |

---

## SECTION 20 — Phase 10 P0 Close-Out Status

| # | Item | Code in repo | Ops remaining |
|---|------|--------------|---------------|
| 1 | Stream token | Pinned Dio + retry, `ChannelResolver`, release assert | Live `STREAM_TOKEN_BASE_URL` |
| 2 | SSL pinning | `SslPinning`, `main()` fail-fast | Production pin hashes |
| 3 | Legal | `legal/*.html` + `LegalConfig` | Host on `lumio.app` |
| 4 | Placeholder guard | `AdConfig.assertReleaseMonetization()` | CI defines for all ad zones |
| 5 | Secrets | `audit_secrets.sh` → `SECRETS_REPORT.md` | Rotate + gitleaks in CI |
| 6 | Zone validation | `ZoneValidator` + diagnostics UI | Device logcat proof |

**Tests:** 113/113 (`flutter test`, 2026-05-28 post fix-sprint). **Analyze:** 0 errors on touched files; legacy warnings remain elsewhere.

---

## SECTION 21 — Audit Coverage Checklist

| Original audit requirement | Covered in report |
|---------------------------|-------------------|
| 12 mandatory sections | **Yes** (§1–12) |
| Four-network ads deep-dive | **Yes** (§3 + diagram) |
| Cloudflare | **Yes** (§13) |
| Phase 10 | **Yes** (§10 + §20) |
| Splash / drawer / favorites / spin | **Yes** (§2) |
| Firebase / Remote Config | **Yes** (§14) |
| Background Adsterra engine | **Yes** (§3.11) |
| Payoneer / crypto | **Yes** — **NOT FOUND** (§19) |
| CI/CD | **Yes** (§16) |
| Payment user IAP | **Yes** — **NOT FOUND** (§15, §19) |
| Workmanager | **Yes** (§8, §14) |
| Coin economy | **Yes** (§15) |
| Catalog data pipeline | **Yes** (§4.1) |
| Docs index | **Yes** (§18) |
| Device-measured fill/eCPM | **No** — static audit only |
| Unused import count | **Not measured** — run analyzer locally |
| 18-item fix sprint | **Yes** (§22) |
| Sideload ads / CAP gate | **Yes** (§23) |
| Product UI / APK size / low-RAM | **Yes** (§24) |

---

## SECTION 22 — Post-Audit Fix Sprint (18-Item Protocol)

**Reference:** `FIX_REPORT.md` (2026-05-28). Client-side implementation complete except partial god-file split and licensed CMP.

| Tier | # | Item | Status |
|------|---|------|--------|
| P0 | 1 | Stream token → pinned Dio + retry | **Done** |
| P0 | 2 | SSL release assert | **Done** (prior) |
| P0 | 3 | Legal HTML (`legal/`) | **Done** — host on `lumio.app` is ops |
| P0 | 4 | Release placeholder guard | **Done** |
| P0 | 5 | `SECRETS_REPORT.md` | **Done** |
| P1 | 6 | HTTP hygiene script | **Done** |
| P1 | 7 | IAB TC string storage | **Partial** |
| P1 | 8 | Remote channels: dart-define + SecureDio + ETag | **Done** |
| P1 | 9–10 | God-file split | **Partial** |
| P1 | 11 | Ad fill analytics + dashboard doc | **Done** |
| P2 | 12 | Wallet API client | **Scaffold** |
| P2 | 13 | Referral service | **Scaffold** |
| P2 | 14 | i18n ARB scaffold | **Scaffold** |
| P2 | 15 | Accessibility | **Partial** |
| P2 | 16 | `legal/app-ads.txt` | **Done** (hosting ops) |
| P2 | 17 | Play Integrity gate | **Gated** |
| P2 | 18 | WebView pool RC + RAM pressure | **Done** |

**New / changed architecture**

- `MultiProvider` in `main.dart`: `ChannelsProvider`, `CoinsProvider`, `AdsSettingsProvider`, `AppProvider`
- `SecureDio.createForBaseUrl()` — per-host pinned clients (stream token, Worker catalog)
- `lib/screens/player_screen_widgets.dart` — extracted player UI widgets

**Verification:** `flutter test` → **113 passed** (2026-05-28).

---

## SECTION 23 — Sideload Ads Verification (2026-06-01)

**Context:** Physical device (MIUI, `com.kakonzone.lumio`), release APK via `tool/build_size_apk.sh` + `secrets.json`. User reported “app works but no ads.” Logcat showed `[ServerCap] ERROR CAP_BASE_URL unset in release — ads disabled` — not ad network failure.

### Root cause chain

| Step | Finding |
|------|---------|
| 1 | `AdManager.adsEnabled` requires `!ServerCap.instance.blocksAdsInRelease` (`lib/ads/ad_manager.dart:57-62`) |
| 2 | `blocksAdsInRelease` = release + empty `CAP_BASE_URL` + not `AdConfig.capLocalOnlyEffective` (`lib/services/server_cap.dart:43-46`) |
| 3 | User `secrets.json` had `CAP_LOCAL_ONLY_MODE` but **invalid JSON** (missing comma after `ADSTERRA_TELEMETRY_URL`) → dart-define omitted trailing keys |
| 4 | Even with valid keys, Play/signed CI APKs without `CAP_LOCAL_ONLY_MODE` or cap API → **zero UI ads** while SDK init may still run |

### Fixes applied (2026-06-01)

| Item | Change |
|------|--------|
| `AdConfig.capLocalOnlyEffective` | `CAP_LOCAL_ONLY_MODE` **or** `LUMIO_SIDELOAD_DEV` (`lib/config/ad_config.dart`) |
| `tool/build_size_apk.sh` | JSON validate + fail if cap URL empty without local mode; sideload adds `CAP_LOCAL_ONLY_MODE=true` |
| `secrets.json` / template | Full key set; `CAP_LOCAL_ONLY_MODE=true`; legal + catalog URLs |
| `AdManager.logRuntimeStatusOnce()` | Release logcat: `[LumioAds] adsEnabled=… blocksCap=…` |
| `.github/workflows/release_apk.yml` | Generated `secrets.json` defaults `CAP_LOCAL_ONLY_MODE=true` when cap URL empty |

### Open bugs (Phase 8 — see `docs/PHASE7_BUGS.md`)

| ID | Severity | Issue |
|----|----------|-------|
| **P8-001** | — | **Fixed** — `LevelPlayRewardedAd` wired end-to-end; privacy screen “Watch ad for ad-free time” |
| **P8-004** | P0 ops | **Mitigated** sideload embedded URL; production still needs real `STREAM_TOKEN_BASE_URL` + pins |
| **P8-005** | — | Player `isStreaming` hides shell ads (by design) |
| P8-002 | — | **Fixed** — build script JSON + CAP guard |
| P8-003 | — | **Fixed** — `capLocalOnlyEffective` |
| P8-006 | — | **Fixed** — CI workflow |
| P8-007 | — | **Fixed** — release `adLog` tags + popunder log |

### Device verification checklist (post-rebuild)

```bash
./tool/build_size_apk.sh
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
adb logcat -c && adb logcat | grep -E "LumioAds|ServerCap|Placement|AdDebug"
```

| Expected log | Meaning |
|--------------|---------|
| `[ServerCap] LOCAL_ONLY_MODE active` | Cap gate open |
| `[LumioAds] adsEnabled=true blocksCap=false` | UI ads allowed |
| `[Placement] aggressive_mode=…` | Placement summary once |
| `[ServerCap] ERROR … ads disabled` | **Fail** — rebuild with fixed `secrets.json` |

**Where ads appear when enabled:** HOME native + 728 + bottom LevelPlay banner; Sports/News/Live banners; list natives every 8 rows; channel-tap interstitial/direct; player mid-roll (not shell chrome while playing).

---

## SECTION 24 — Product UI, Size & Performance Sprint (2026-06-01)

**Context:** Post–Section 23 sideload fixes; focus on HOME UX, install footprint, Android 5.0+ support, and smooth behavior on 2 GB RAM phones.

### 24.1 UI / product changes

| Area | Change | Evidence |
|------|--------|----------|
| Promo carousel | FIFA WC26 PNG banners (assets) + 3 gradient slides; 5s auto-scroll | `assets/images/fifa_wc26_banner_*.png`, `home_promo_carousel.dart` |
| Home categories | 3-color gradient tiles, emoji, glass icon, LIVE pulse | `home_category_grid.dart` |
| Browse tab categories | Gradient `_GenreCategoryCard` / `_WideGenreCard` | `other_screens.dart` |
| Bottom nav | Per-tab accent gradient when active | `main_shell_bottom_nav.dart` |
| Home sub-tabs | Icon + gradient pills (Home/Live/Today/Soon) | `tv_screen.dart` `_tabBar` |
| Live event cards | Sport/live gradients, watermark flags, larger avatars | `tv_screen.dart` `_LiveEventCard` |
| Live event channels | **All links unlocked** — instant play; improved matcher pool | `_LiveEventChannelsDialog`, `match_channel_matcher.dart` |
| News tab | World Cup → Cricket priority; hero images; vibrant cards | `news_priority.dart`, `news_article_card.dart` |
| Startup | Fast splash; home-first; deferred app-open promo / interstitial | `splash_screen.dart`, `AdManager.warmupAfterHomeVisible` |

### 24.2 Build & size policy

| Target | Policy |
|--------|--------|
| **Default ship (rev.5)** | **`BUILD_APK_MODE=split`** — **two APKs**: `app-arm64-v8a-release.apk` + `app-armeabi-v7a-release.apk` |
| Download per device | **~22–40 MB** each (`MIN_APK_MB`–`MAX_APK_MB` in `tool/build_release_apk.sh`) |
| Fat APK (optional) | `BUILD_APK_MODE=fat` → one file **~45–55 MB** (both ABIs) |
| arm64-only (optional) | `BUILD_APK_MODE=arm64` |
| Installed | **~60–80 MB** with `AppStorageGuard` + tiered image cache |
| minSdk | **21** (Android 5.0+) via Flutter `minSdkVersion` |
| Optional shrink | `FIREBASE_ENABLED=false` in `secrets.json` (~3–5 MB) |
| Doc note | `docs/ANDROID_SIZE_AND_PERFORMANCE.md` still describes fat-as-default — **use this report + `tool/build_release_apk.sh` comments** for current policy |

### 24.3 Low-RAM performance

| Mechanism | Behavior |
|-----------|----------|
| `PerformanceTuning.apply()` | Called at start of `main()` before `runApp` |
| RAM tiers | low (&lt;~2.8 GB) / normal / high — from `ActivityManager` |
| ImageCache | 24–72 MB cap by tier |
| Player buffer | 2–4 MB `media_kit` buffer by tier |
| Lists | Lower `cacheExtent` on low tier; repaint boundaries on Home/Browse |
| Cache trim | `AppStorageGuard` on startup, resume, 6h periodic |

### 24.4 Build fix (FootyStream)

| Issue | Fix |
|-------|-----|
| `toffeeHeaders` undefined in `footystream_service.dart` | Removed invalid spread; FootyStream uses browser `User-Agent` + `Accept` only (not Toffee CDN) |

### 24.5 Verification commands

```bash
./tool/build_release_apk.sh
# or size/sideload QA:
./tool/build_size_apk.sh
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
adb shell dumpsys package com.kakonzone.lumio | grep -E 'codeSize|dataSize'
```

**Not re-run in this update:** release APK byte size on device (run locally after build).

---

## SECTION 25 — Catalog, APK Split, Ads & Matcher Sprint (2026-06-02)

**Context:** Full-app re-audit after GitHub-only channel catalog, split APK default, ads placeholder fixes, and real monetization keys in `secrets.json`.

### 25.1 Channel catalog (GitHub-only)

| Item | Status |
|------|--------|
| Single playlist URL | `https://github.com/kakonzone/allchannelking.m3u8/blob/main/allchannelking.m3u8` |
| `includeAllChannels: true` | Full M3U categories preserved |
| `AppProvider` | No hardcoded channel list; loads via `CatalogService` |
| Bundled assets | `user_playlist.m3u` / `scanned_iptv.m3u` **removed** from `pubspec.yaml` |
| Special Link UI | GITUN hub only; CricHD services **deleted** |
| Local playlist file | User maintains `~/allchannelking.m3u8` → push to GitHub |

### 25.2 APK build (32-bit + 64-bit)

| Item | Detail |
|------|--------|
| Entry script | `./tool/build_release_apk.sh` |
| Default | `--split-per-abi` → install **one** APK matching phone CPU |
| 64-bit phones | `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |
| 32-bit phones | `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` |
| Defines | `--dart-define-from-file=secrets.json` + `LUMIO_SIDELOAD_DEV=true` + `CAP_LOCAL_ONLY_MODE=true` when set |
| Pre-build checks | Valid JSON; required secrets; **no template/example.com ad keys** |
| Obfuscation | `--obfuscate` + `--split-debug-info` |
| Distribution | Sideload (WhatsApp/Drive/`adb install`) — **not Play Store** |

**Common APK problems (mitigated):**

| Problem | Mitigation |
|---------|------------|
| Ads silent in release | `CAP_LOCAL_ONLY_MODE=true`; valid LevelPlay/Adsterra keys; logcat `[LumioAds]` |
| Build passes but ads fake | Build script rejects `example.com` / `আপনার_*` placeholders |
| Wrong APK on phone | Do not install arm64 APK on 32-only device (and vice versa) |
| Parse error Android 5–6 | Release script uses APK v1 signing for Lollipop |
| Huge download | Use **split** mode, not `BUILD_APK_MODE=fat`, for sideload shares |

### 25.3 Monetization stack (configured)

| Network | Integration | Notes |
|---------|-------------|-------|
| **LevelPlay** | `unity_levelplay_mediation` | App key + Interstitial/Rewarded/Banner unit IDs in `secrets.json` |
| **Unity Ads** | Dashboard mediation only | Game ID **800000664** — not in Dart; link in LevelPlay console |
| **Adsterra** | WebView zones: Native, Social, Popunder, 728×90 | `AdsterraHtml` + existing widgets |
| **Adsterra direct** | Monetag smartlink URL used for browser channel-tap | `adsterraDirectLinksReleaseSafe` |
| **Monetag** | `PropellerEngine` / `PropellerHtml` | All 5 zones + hosts in `secrets.json` |
| **Firebase** | `FIREBASE_ENABLED=false` | Push/Crashlytics/RC off; ads use compile-time config + RC defaults when off |

**Ad code hygiene (2026-06-02):** `hasValidLevelPlay*`, `hasValidAdsterra*`, `adsterraDirectLinksReleaseSafe`, `assertReleaseMonetization()`, rotators use release-safe URLs.

### 25.4 Tests & open items

| Item | Status |
|------|--------|
| `flutter test` | **122 passed, 4 failed** (2026-06-02) — fix widget/shell failures before release tag |
| Analyzer | Run `flutter analyze` locally |
| Legal URLs | `secrets.json` still has `yourusername.github.io` placeholders — host real policy pages |
| `STREAM_TOKEN_BASE_URL` | Set for production token signing (sideload may use local caps only) |

### 25.5 Verification commands

```bash
cd ~/Downloads/FlutterProject/lumio
./tool/build_release_apk.sh
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
adb logcat | grep -E 'LumioAds|LevelPlay|Adsterra|Gitun'
flutter test
```

---

## Summary Table

| Section | Score (1–10) | Critical issues |
|---------|--------------|-----------------|
| 1 Project health | **8** | 186 dart files; `AppProvider` ~939 LOC; 122/126 tests pass |
| 2 Pages / features | **8** | GitHub catalog; FootyStream; matcher-driven live events |
| 3 Ads (4-network) | **9** | Real keys in `secrets.json`; placeholder build guard; valid-config getters |
| 4 Streaming | **7** | GitHub M3U only; strong matcher; HTTP streams in playlist remain |
| 5 Security | 6 | Pins + secrets report; cleartext + WebView risk |
| 6 Performance | **7** | Size targets documented; `PerformanceTuning` + storage guard; fast startup path |
| 7 Tier-1 | 4 | ARB scaffold; no licensed CMP |
| 8 Acquisition | 7 | Referral scaffold; deep links + FCM |
| 9 Revenue model | 6 | Fill/sideload capped |
| 10 Gaps | — | P0 ops: token API, legal host, CI defines |
| 11 Code quality | **6** | God-file reduced; matcher well-documented in code |
| 12 Verdict | **8** | **85%** sideload launch — fix 4 tests + legal URLs |
| 13 Cloudflare | **5** | Worker URL in secrets but catalog path is GitHub-only |
| 14 Firebase / backend | 7 | Optional Crashlytics; RC kill switches |
| 15 Coins / ad-free | 6 | Wallet API scaffold; client coins |
| 16 Native / CI | **9** | Split APK default; monetization preflight; minSdk 21 |
| 17 Dependencies | 8 | Mature stack; dual WebView libs |
| 18 Docs | 9 | FIX_REPORT, BACKEND_CHECKLIST, legal/ |
| 19 Payoneer / crypto | 0 | **NOT FOUND** in app |
| 20 Phase 10 + fix sprint | 9 | Client P0/P1 largely done; ops open |
| 21 Coverage | — | Checklist complete |
| 22 Fix sprint | 9 | See `FIX_REPORT.md` |
| 23 Sideload ads | 9 | Phase 8 bugs fixed except prod stream-token host |
| 24 Product / size / perf | **8** | UI sprint + `PerformanceTuning`; split APK policy |
| 25 Catalog / APK / ads | **9** | GitHub-only channels; split 32/64; ads keys + matcher doc |

**Report version:** 2026-06-02 **rev.5** (Section 25; canonical file: `AUDIT_REPORT.md`). Mirror: `docs/AUDIT_REPORT_v2.md` — sync header only.

---

*End of audit. Report generated from static analysis only; device fill rates and eCPM require production measurement.*
