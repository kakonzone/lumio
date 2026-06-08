# Lumio Sports TV — Forensic Technical & Business Audit

**Audit date:** 2026-05-28  
**Last updated:** 2026-06-08 **rev.10** — **CI/CD optimization & Appwrite dual-config** (Gradle memory, Kotlin alignment, featured events, special links)  
**Scope:** Full repo (`lib/`, `android/`, `assets/`, `pubspec.yaml`, Gradle, manifests, docs)  
**Distribution model:** Sideload APK (not Play Store) — Facebook / WhatsApp / Telegram / landing page  
**Monetization focus:** IronSource LevelPlay + Unity (mediation only) + Adsterra + Monetag  
**Infrastructure note:** Channel catalog + featured config on **Appwrite** (Guests Read) — see **Section 13**. **No Cloudflare** in the app ship path.

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
| 13 | Appwrite (catalog backend) |
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
| 26 | Anti-analysis: blocked-app gate + Play Integrity roadmap (2026-06-04) |
| 27 | UI density, lazy ads & APK size sprint (2026-06-04) |
| 28 | Forensic P0/P1 fix sprint (2026-06-04) |
| 29 | CI/CD optimization & Appwrite dual-config (2026-06-08) |

---

## SECTION 1 — Project Health Snapshot

| Metric | Value | Evidence |
|--------|-------|----------|
| Flutter SDK | **3.41.6** (stable) | `flutter --version` |
| Dart SDK | **3.11.4** | `flutter --version` |
| compileSdk / targetSdk / minSdk | **36 / 36 / 21+** | `minSdk = maxOf(21, flutter.minSdkVersion)` — **Android 5.0 (Lollipop)+** (`android/app/build.gradle.kts`) |
| lib `.dart` files | **226** | `find lib -name '*.dart'` (2026-06-08) |
| lib LOC (approx.) | **~42,861** | `wc -l` on `lib/**/*.dart` (2026-06-08) |
| State management | **Provider** (`MultiProvider`) | `lib/main.dart` — `ChannelsProvider`, `CoinsProvider`, `AdsSettingsProvider`, `AppProvider` |
| Architecture | **Pragmatic layered monolith** — screens + `AppProvider` god-state + ad singletons | No Clean/MVVM boundaries; ad stack is well-factored into `lib/ads/` |
| Folder structure score | **6/10** | Good `lib/ads/`, `lib/services/`, `lib/security/` split; undermined by 3.5k+ LOC god files |
| TODO/FIXME in `lib/` + `android/` | **0** matches | `rg TODO\|FIXME` — none found |
| Unit/widget tests | **67 test files** | `find test -name '*.dart'` (2026-06-08) |
| Test coverage | **113+ passing** | `flutter test` (baseline from 2026-05-28) |
| Dead code | **Low–medium** | Duplicate `ironsource_service` paths (`lib/services/` vs `lib/ads/`); large embedded channel catalogs |
| **Package name** | `com.kakonzone.lumio` | `android/app/build.gradle.kts:100-101` |
| **Pub package** | `lumio_tv` v`1.0.0+1` | `pubspec.yaml:1-3` |
| **Ship target** | **Android APK (primary)** | `media_kit_libs_android_video`; sideload distribution |
| **iOS / desktop in repo** | **Present but not product focus** | `macos/`, `ios/` folders exist; audit scope = Android ship path |
| **Test files** | **39** Dart files under `test/` | `find test -name '*.dart'` |
| **Docs** | **95+** Markdown files under `docs/` | includes Phase 10, smoke tests, secrets (2026-06-08) |
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
| **Shell** | **`NestedScrollView`** — search + tab bar pinned; tab bodies scroll independently (`tv_screen.dart`) |
| **Promo carousel** | FIFA WC26 **WebP** banners + gradient slides; promo scrolls **inside Home tab only** (`home_promo_carousel.dart`) |
| **Browse grid** | **`HomeCategoryGrid`** — 3×2 gradient category tiles, emoji, LIVE pulse, channel counts (`lib/widgets/home_category_grid.dart`) |
| **All Live Events** | Gradient match cards, team flags (`TeamAvatar`), tap → channel dialog — **all links unlocked** (no match-started / health gate) |
| **Schedules** | **FootyStream** `/pk` + `/today` merged with ESPN/Cricbuzz via `ScheduleMerge` + `LiveEventsService` (`lib/services/footystream_service.dart`) |
| **Channel matching** | `MatchChannelMatcher.channelPoolFor` — Sports + regional cats (BD/PK/IN/EN); team name in channel metadata scoring |
| **Working** | Category drill-down, favorites hooks, `openChannelPlayer`, fast catalog + background full merge (`AppProvider.init`) |
| **Ads** | **`LazyAdViewport`** / `LazyAdsterra*` (`placeholderHeight: 0` off-screen) — native top + 728 bottom; LevelPlay shell banner |
| **Loading / error** | **Yes** — `RefreshIndicator` + `ChannelListSkeleton` |
| **Pull-to-refresh** | **Yes** |
| **Offline cache** | **Partial** — GitHub M3U cached 1h (`SpecialLinkConfig.gitunCacheTtl`) + in-memory catalog; no full offline playback |
| **Skeleton loaders** | **Yes** |

### SPORTS (`SportsScreen`)

| Item | Detail |
|------|--------|
| **File** | `lib/screens/other_screens.dart` (`SportsScreen` ~147+) |
| **Working** | Sport filter pills (All / Cricket / Football / …); **3×N gradient category grid** on **All**; tap sport → filtered channel list with priority sort |
| **Removed (rev.8)** | **“All sports channels”** full browse list under grid — redundant with grid drill-down |
| **Ads** | `LazyAdsterraBanner728` (`sports_top`); native **`sports_categories`** below grid; list natives when filtered; `TabAdOverlay` floating native |
| **Loading / error** | **Yes** — skeletons + refresh |
| **Pull-to-refresh** | **Yes** |
| **Skeleton** | **Yes** (`ChannelListSkeleton`, `CategoryGridSkeleton`) |

### LIVE (`LiveScreen`)

| Item | Detail |
|------|--------|
| **File** | `lib/screens/other_screens.dart` (`LiveScreen` ~538+) |
| **Working** | **`ScreenStatChips`** (live / sports / movies counts, **centered**); TOP SPORTS + regional HLS groups + movies; `LiveTabChannels` / `LiveNavTopSports` |
| **Ads** | `LazyAdsterraBanner728` (`live_top`); `AdListInjector` natives in flattened list |
| **Loading / error** | **Yes** |
| **Pull-to-refresh** | **Yes** |
| **Skeleton** | **Yes** |

### NEWS (`NewsScreen`)

| Item | Detail |
|------|--------|
| **File** | `lib/screens/news_screen.dart`, `lib/screens/news_article_reader_screen.dart` |
| **Working** | Category pills (All, Top Stories, Cricket, …); optional Premier scores; World Cup/Cricket chips; hero + article list |
| **Ads** | **Immediately after category nav** — `LazyAdsterraBanner728` + `LazyAdsterraNativeBanner` (`news_headlines`); inline via `ad_placement_news.dart` |
| **Layout** | Fixed **`ShellAppBar`** + scroll body (no duplicate sticky header gap) |
| **Loading / error** | **Yes** — refresh on feed |
| **Pull-to-refresh** | **Yes** |
| **Skeleton** | **Partial** (list-level; not as heavy as HOME) |

### SPECIAL LINK (`SpecialLinkListScreen`)

| Item | Detail |
|------|--------|
| **File** | `lib/screens/special_link/special_link_list_screen.dart` (`SpecialLinkHubScreen` typedef) |
| **Working** | GITUN M3U channels only; `GitunPlaylistService` + `SpecialLinkCache` (1h TTL) |
| **Shell** | **`ShellPageScaffold`** — channel count as **`ShellAppBar` subtitle** (no extra scroll gap under bar) |
| **Ads** | `LazyAdsterraBanner728` (`special_link_top`); list natives via `AdListInjector` |
| **Empty state** | `SizedBox.shrink()` — no tall placeholder under app bar |

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
| Placements (sample) | HOME/Sports/Live/News/Special Link via **`LazyAdsterra*`**; global social bar; 1×1 popunder host | `lazy_adsterra_strip.dart`, `tv_screen.dart`, `other_screens.dart`, `news_screen.dart` |
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
| **Quality switching** | **Yes** — manual 540p / 720p / 1080p; **default 540p** on mobile; auto-clamp 720p without Wi‑Fi + charging |
| **Android decode** | **`hwdec=mediacodec`** (H.264/HEVC/VP9/AV1); probe/prewarm gated to idle playback | `player_screen.dart`, `lib/core/perf/player_tuning_notes.md` |
| **Origin** | **Mixed CDN + direct IPs** — cleartext allowlist for legacy hosts | `network_security_config.xml` + `tool/gen_network_security_config.py` |
| **HTTP in `app_provider.dart`** | **~2** references (not embedded catalog) | Catalog URLs live in remote M3U only |
| **Latency** | **ESTIMATE 4–15s** start (HLS + HTTP origins + token round-trip) | — |
| **Concurrent viewers** | **NOT VISIBLE** in client — no backend viewer count | — |
| **DRM** | **NOT FOUND** (Widevine) | — |
| **Token protection** | **Stronger client-side** | `StreamTokenService` — **pinned Dio** (`SecureDio.createForBaseUrl`), **3× retry**, 8s timeout; `ChannelResolver`; requires live `STREAM_TOKEN_BASE_URL` |
| **Credentialed URLs in source** | **0** `user:pass@` in `lib/` | Grep clean |
| **Stability rating** | **5/10** | Strong player logic undermined by HTTP origins, cleartext hosts, token backend not guaranteed in ops |
| **Catalog backend** | **Appwrite** | `CatalogService` → `AppwriteService` — Section 13 (not Cloudflare) |

### 4.1 Data sources (channel catalog pipeline) — **rev.7**

| Source | Priority | Evidence |
|--------|----------|----------|
| **Appwrite Databases** | **Primary (main app)** | `CatalogService.loadCatalog` → `AppwriteService.fetchChannels` — `lib/services/catalog_service.dart` |
| Collections | `channels` + `app_config` (featured live events) | `lib/config/appwrite_config.dart` |
| Auth model | **Guests Read only** — no API key in APK | `lib/services/appwrite_service.dart`, `docs/SECRETS.md` |
| UI state | `AppProvider` loads via `CatalogService` | `lib/provider/app_provider.dart` — comment: “Main catalog: Appwrite only” |
| **GITUN / GitHub M3U** | **Secondary** (Special Link browse) | `GitunPlaylistService` — not the home/sports/live catalog |
| **Removed / legacy** | — | `RemoteChannelsService` + `REMOTE_CHANNELS_URL` (old Worker URL) — **not** used by `CatalogService`; embedded `_hardcodedChannels` removed from ship path |
| Stream token API | Optional signing | `StreamTokenService` — `STREAM_TOKEN_BASE_URL` |
| Stream health scan | After catalog load | `stream_health_service.dart` |

**Ops:** Update main channels in **Appwrite Console** (`iptv_main` / `channels`); featured cards via `app_config` document keys. GITUN playlist still updated via GitHub push when that hub is used.

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
| Root / emulator / debugger / Frida / Xposed | **YES** | `security_manager.dart` — 60s watchdog; strict release → `exit(1)` |
| Native anti-tamper (JNI) | **YES** | `liblumio_security.so` — ptrace + `/proc/self/maps` Frida scan (`secrets.cpp`) |
| **Conflicting-app blocklist** | **YES (2026-06-04)** | `BlockedAppDetector.kt` — 17 XOR-encoded packages; startup gate + resume overlay |
| VPN block | **Off by default** | `security_config.dart` — `blockVpn = false` |
| APK signature check | **Optional** (empty hash = skip) | `security_config.dart` — `expectedApkSignatureSha256` |
| Play Integrity (client) | **Disabled v1.0** | Option B — no `X-Integrity-Token`; `PlayIntegrityService` stub until v1.1 (`docs/PLAY_INTEGRITY_OPTION_B.md`) |
| Play Integrity (server) | **NOT DEPLOYED** | Decode endpoint planned on `CAP_BASE_URL` / stream API — **not** Appwrite catalog (`docs/PLAY_INTEGRITY_SERVER.md`) |

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

### 5.9 Conflicting-app gate (anti-analysis) — **rev.6**

| Item | Detail |
|------|--------|
| **Trigger** | HttpCanary, PCAPdroid, Magisk, LSPosed, HTTP Toolkit, Parallel/Dual Space, etc. (17 packages) |
| **Native scan** | `BlockedAppDetector.kt` — XOR `@ 0xA7` (matches `secrets.cpp` key); `PackageManager.getPackageInfo` |
| **Manifest visibility** | `<queries><package …/></queries>` per blocked package — Android 11+ (`AndroidManifest.xml`) |
| **Flutter gate** | `main()` → `BlockedAppsGuard` before `runApp`; full-screen Bengali UI (`blocked_apps_screen.dart`) |
| **Runtime re-check** | `BlockedAppsOverlay` on app resume (`widgets/blocked_apps_overlay.dart`) |
| **User actions** | **আনইনস্টল করুন** → `Settings.ACTION_APPLICATION_DETAILS_SETTINGS`; **বন্ধ করুন** → `SystemNavigator.pop()` |
| **MethodChannel** | `findBlockedAppLabels`, `openFirstBlockedAppUninstall` on `com.lumio.security/native` |
| **Config** | `SecurityConfig.blockConflictingApps = true`; bypass: `kDebugMode` + `bypassChecksInDebug`, or `LUMIO_SIDELOAD_DEV` |
| **Trust level** | **Client-only** — patchable; pairs with server attestation (v1.1) for real stream protection |
| **Pro pattern gap** | Local gate ≠ server deny — stream tokens still need Play Integrity decode on backend |

### 5.10 Risk score: **HIGH** (unchanged overall)

| # | Vulnerability | Severity |
|---|---------------|----------|
| 1 | Monetag default zones + hosts committed — zone hijack / policy if not overridden in release | High |
| 2 | 76+ HTTP stream URLs + cleartext network config — MITM on playback | High |
| 3 | Ad WebViews with unrestricted JS + third-party ad scripts — WebView supply-chain | High |
| 4 | No licensed CMP — TC string storage only | High (business) |
| 5 | Sideload + aggressive ad UX — store/network ban risk | Medium–High |
| 6 | Blocked-app gate bypassable — no server Play Integrity yet | Medium (mitigated for casual sniffers) |

---

## SECTION 6 — Performance & UX

| Item | Finding |
|------|---------|
| **APK download (release)** | **Target 20–35 MB** per ABI — `MIN_APK_MB=20` `MAX_APK_MB=35` in `tool/build_release_apk.sh`; `--split-per-abi` or `BUILD_APK_MODE=arm64` for single 64-bit file |
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
| 8 | Appwrite catalog | **Done** — `AppwriteService`, Guests Read | Console permissions + collection schema; drop `REMOTE_CHANNELS_URL` from ops docs |
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
| 17 | Play Integrity | **Gated** — client Option B off; server decode not deployed | v1.1: restore native bridge + `CAP_BASE_URL` decode (not Appwrite catalog) |
| 19 | Conflicting-app blocklist | **Done (client)** — Section 5.9 | v1.1: combine with server attestation for stream/cap gate |
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

## SECTION 13 — Appwrite Backend (Catalog)

**Verdict:** Lumio’s **main channel catalog and featured live-event config** are served from **Appwrite Databases** (`dart_appwrite`). There is **no Cloudflare Workers/Pages integration** in the active catalog path. Legacy `RemoteChannelsService` (Workers URL) remains in the repo but is **not** called by `CatalogService`.

### 13.1 Active runtime (Appwrite)

| Use | Status | Evidence |
|-----|--------|----------|
| **Channel list** | **ACTIVE** | `AppwriteService.fetchChannels` — database `iptv_main`, collection `channels` |
| **Featured World Cup / home cards** | **ACTIVE** | `app_config` collection — key `featured_live_events` (`docs/APPWRITE_WORLD_CUP_CARDS.md`) |
| **Client SDK** | `dart_appwrite: ^25.0.0` | `pubspec.yaml` |
| **Endpoint / project** | Dart-define | `APPWRITE_ENDPOINT`, `APPWRITE_PROJECT_ID` — `lib/config/appwrite_config.dart` |
| **Permissions** | **Guests Read** on `channels` + `app_config` | `docs/SECRETS.md` — **no** `APPWRITE_API_KEY` in app |
| **Load path** | `CatalogService.loadCatalog` → normalize on isolate | `lib/services/catalog_service.dart` |
| **Error UX** | Empty fetch → user-visible error + pull-to-refresh | `CatalogLoadResult.errorMessage` |

```dart
// lib/services/catalog_service.dart — main catalog source
final channels = await AppwriteService.instance.fetchChannels(
  forceRefresh: forceRefresh,
);
```

### 13.2 Secondary: GITUN (GitHub M3U)

| Use | Status | Evidence |
|-----|--------|----------|
| Special Link / GITUN browse | **Separate** from main catalog | `GitunPlaylistService`, `SpecialLinkCache` |
| Not a replacement for Appwrite home/sports/live | Documented in `AppProvider` | “Main catalog: Appwrite only” |

### 13.3 Legacy / NOT USED (removed from audit scope)

| Item | Status | Note |
|------|--------|------|
| `REMOTE_CHANNELS_URL` / `lumio-channels.*.workers.dev` | **Legacy code only** | `remote_channels_service.dart` — superseded by Appwrite |
| Cloudflare Workers catalog | **NOT IN SHIP PATH** | Removed from this audit — not Lumio infrastructure |
| `wrangler.toml` in repo | **NOT FOUND** | — |

### 13.4 Ops implications

1. **Single point of failure:** Appwrite outage → empty catalog + error UI (no silent embedded fallback).  
2. **Updates:** Edit documents in Appwrite Console or migration scripts — clients refresh on pull-to-refresh / cache TTL.  
3. **Security:** Never put API keys in APK; rotate leaked keys in Console immediately (`docs/SECRETS.md`).  
4. **Stream URLs** in channel rows may still point to third-party HTTP/HLS hosts — transport risk is per-row, not Appwrite hosting.

### 13.5 VPN note (1.1.1.1 app — not Appwrite)

The app may **detect** the Cloudflare 1.1.1.1 / WARP **client app** as a VPN signal for **ad routing only** (`vpn_asn_catalog.dart`). This is unrelated to catalog hosting on Appwrite.

### 13.6 Appwrite score

| Aspect | Score (1–10) | Note |
|--------|--------------|------|
| Integration maturity | **8** | Dedicated service + config; clear Guests Read model |
| Security | **7** | No API key in client; public-read catalog by design |
| Operational readiness | **7** | Depends on Console permissions + collection health |
| **Cloudflare in app** | **0 / N/A** | Not used for catalog — **Appwrite replaces prior Worker design** |

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
| `REMOTE_CHANNELS_URL` | **Legacy** (unused by catalog) | `remote_channels_service.dart` — prefer Appwrite; optional dart-define for experiments only |
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
| **Obfuscated release script** | `tool/build_release_apk.sh` — split ABI, tree-shake, `MIN_APK_MB=20` `MAX_APK_MB=35`, optional `BUILD_LEGACY_ABI` | Enforces legal + stream token + LevelPlay + Adsterra |
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
| `docs/ANDROID_SIZE_AND_PERFORMANCE.md` | APK **20–35 MB**, install 60–80 MB, Android 5.0+, low-RAM |
| `docs/DEEP_LINK_ATTRIBUTION.md` | Campaign URLs |
| `docs/SIDELOAD_UPDATE.md` | APK update manifest |
| `docs/APP_ADS_TXT_TEMPLATE.md` | app-ads.txt |
| `docs/LEGAL_HOSTING.md` | Legal page hosting options (hosting provider agnostic) |
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
| Appwrite catalog | **Yes** (§13) |
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
| GitHub catalog / split APK / ads sprint | **Yes** (§25) |
| Blocked-app anti-analysis gate | **Yes** (§5.9, §26) |
| Play Integrity / Appwrite architecture | **Yes** (§5.5, §26.4) |

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
| P2 | 17 | Play Integrity gate | **Gated** — client Option B; server decode v1.1 |
| P2 | 18 | WebView pool RC + RAM pressure | **Done** |
| P2 | 19 | Conflicting-app blocklist gate | **Done** (2026-06-04) — §26 |

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

**Where ads appear when enabled:** HOME/Sports/News/Live **`LazyAdsterra*`** strips (zero off-screen placeholder); list natives every 8 rows; channel-tap interstitial/direct; player mid-roll (not shell chrome while playing).

---

## SECTION 24 — Product UI, Size & Performance Sprint (2026-06-01)

**Context:** Post–Section 23 sideload fixes; focus on HOME UX, install footprint, Android 5.0+ support, and smooth behavior on 2 GB RAM phones.

### 24.1 UI / product changes

| Area | Change | Evidence |
|------|--------|----------|
| Promo carousel | FIFA WC26 **WebP** banners (~400 KB saved vs PNG) + 3 gradient slides; 5s auto-scroll | `assets/images/fifa_wc26_banner_*.webp`, `home_promo_carousel.dart` |
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
| Download per device | **~20–35 MB** each (`MIN_APK_MB=20`, `MAX_APK_MB=35` in `tool/build_release_apk.sh`) |
| Fat APK (optional) | `BUILD_APK_MODE=fat` → one file **~45–55 MB** (both ABIs) |
| arm64-only (recommended sideload) | `BUILD_APK_MODE=arm64 ./tool/build_size_apk.sh` → **one** 64-bit APK **~20–35 MB** |
| Installed | **~60–80 MB** with `AppStorageGuard` + tiered image cache |
| minSdk | **21** (Android 5.0+) via Flutter `minSdkVersion` |
| Optional shrink | `FIREBASE_ENABLED=false` in `secrets.json` (~3–5 MB); optional `scripts/font_subset.py` |
| Doc | `docs/ANDROID_SIZE_AND_PERFORMANCE.md` aligned with **20–35 MB** policy (rev.8) |

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

**Context:** Re-audit after **Appwrite** main catalog, split APK default, ads placeholder fixes, and real monetization keys in `secrets.json`. (Rev.7: Cloudflare Worker catalog **removed** from ship path.)

### 25.1 Channel catalog (Appwrite primary)

| Item | Status |
|------|--------|
| Main catalog | **Appwrite** `iptv_main` / `channels` via `CatalogService` |
| Featured cards | **Appwrite** `app_config` / `featured_live_events` |
| `AppProvider` | Loads via `CatalogService` — no hardcoded channel list |
| GITUN hub | GitHub M3U — **secondary** Special Link path only |
| Bundled assets | `user_playlist.m3u` / `scanned_iptv.m3u` **removed** from `pubspec.yaml` |
| Legacy Worker URL | `REMOTE_CHANNELS_URL` — code remains, **not** used by catalog loader |

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
| Legal URLs | `secrets.json` → `kakonzone.github.io/lumio/*` (rev.7 pre-ship) |
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

## SECTION 26 — Anti-Analysis Sprint: Blocked-App Gate (2026-06-04)

**Context:** Client-side anti-tamper layer — refuse launch when MITM / RE / hooking / cloning apps are installed. Aligns with industry “defense in depth” layer 1; server Play Integrity remains layer 5 (not shipped).

### 26.1 Implementation summary

| Layer | Component | File(s) |
|-------|-----------|---------|
| Android scan | XOR blocklist + label resolution | `android/.../BlockedAppDetector.kt` |
| Manifest | Package visibility (API 30+) | `android/app/src/main/AndroidManifest.xml` `<queries>` |
| Native bridge | MethodChannel handlers | `MainActivity.kt` — `findBlockedAppLabels`, `openFirstBlockedAppUninstall` |
| Dart guard | Enforce + bypass rules | `lib/security/blocked_apps_guard.dart` |
| Startup gate | Block before main app | `lib/main.dart` — `BlockedAppsGuard` → `BlockedAppsScreen` |
| Resume gate | Overlay on lifecycle resume | `lib/widgets/blocked_apps_overlay.dart` |
| UI | Bengali full-screen block | `lib/screens/blocked_apps_screen.dart` |
| Config flag | `blockConflictingApps` | `lib/security/security_config.dart` |

### 26.2 Blocked package categories (17)

| Category | Examples (decoded) |
|----------|-------------------|
| Packet capture / MITM | HttpCanary, SSL Capture, PCAPdroid, ProxyMon, HTTP Toolkit |
| Hooking / root | Xposed, LSPosed, Magisk (official + fork) |
| Proxies | Proxyman NSProxy |
| App cloners | Parallel Space, Dual Space, DualAid |

Strings stored XOR-encoded in Kotlin — not plaintext in DEX.

### 26.3 Bypass / test modes

| Mode | Behavior |
|------|----------|
| `kDebugMode` + `bypassChecksInDebug` | Gate skipped (dev with HttpCanary) |
| `LUMIO_SIDELOAD_DEV=true` | Gate skipped (USB sideload QA) |
| Release (default) | Gate **on** — app does not proceed until conflicting apps removed |

### 26.4 Play Integrity & Appwrite — professional architecture (documented, not implemented)

| Concern | Recommended placement | Lumio status |
|---------|----------------------|--------------|
| Channel catalog | Appwrite DB — **Guests Read** | **Active** — no API key in app |
| Blocked-app scan | Android client | **Active** (rev.6) |
| Play Integrity **decode** | Stream/cap backend (`CAP_BASE_URL`, `STREAM_TOKEN_BASE_URL`) | **Planned v1.1** — `docs/PLAY_INTEGRITY_SERVER.md` |
| Appwrite Functions for integrity | Possible but **not recommended** for Lumio — splits trust layer away from cap/stream API | **Not used** |
| Real stream protection | Short-lived signed URLs + server attestation | Partial — `StreamTokenService` exists; integrity header omitted (Option B) |

**Pro rule:** Appwrite = public catalog; **never** put Google service-account secrets or integrity decode in the same Guests-read path.

### 26.5 Verification commands

```bash
# Static — blocklist files present
rg -l 'BlockedAppDetector|BlockedAppsGuard|blockConflictingApps' lib/ android/

# Release device — install HttpCanary (test phone), launch Lumio → expect block screen (not splash)
adb logcat | grep -E 'Lumio|blocked'

# After uninstall conflicting app → tap "আবার যাচাই করুন" or relaunch → app proceeds
```

### 26.6 Open items (security roadmap)

| Priority | Item | Owner |
|----------|------|-------|
| P1 | Deploy Play Integrity decode on cap/stream backend | Backend |
| P1 | Restore `PlayIntegrityBridge.kt` + send `X-Integrity-Token` (v1.1 Option A) | Mobile |
| P2 | Set `expectedApkSignatureSha256` for release keystore | Release |
| P2 | Move blocklist scan to JNI (harder to patch) | Android |
| P3 | Nonce replay store (Redis / backend) for integrity tokens | Backend |

---

## SECTION 27 — UI Density, Lazy Ads & APK Size Sprint (2026-06-04)

**Context:** Post–rev.7 polish — remove scroll dead space on nav tabs, align ad loading with Home (`LazyAdViewport`), tighten release APK budget to **20–35 MB**, and ship player thermal/decode fixes on `hotfix/player-perf-wc`.

### 27.1 Navigation UI (spacing)

| Screen | Change | Evidence |
|--------|--------|----------|
| **Home** | Promo inside Home tab `CustomScrollView`; tighter `SliverPadding` between Browse / featured / live sections | `tv_screen.dart` `_HomeTab` |
| **Sports** | Removed **“All sports channels”** list on **All** filter; native ad **below** sport grid; reduced pill/ad padding | `other_screens.dart` `_sportsAllSlivers`, `_sportsBrowseListSlivers` removed |
| **Live** | **`ScreenStatChips`** centered (`Center` + `WrapAlignment.center`) | `section_nav_bar.dart` |
| **News** | Ads **directly under** category pills (before scores); `ShellAppBar` fixed header; tighter `_NewsSectionHeader` padding | `news_screen.dart` |
| **Special Link** | Channel count in **`ShellAppBar` subtitle** (not duplicate scroll row); top banner `padding: 0` top; empty → `SizedBox.shrink()` | `special_link_list_screen.dart`, `shell_page_scaffold.dart` |

### 27.2 Lazy ad strips (Home pattern)

| Widget | Behavior | File |
|--------|----------|------|
| `LazyAdViewport` | `placeholderHeight: 0` until within `preloadPx` of viewport | `lib/ads/utils/lazy_ad_viewport.dart` |
| `LazyAdsterraBanner728` / `LazyAdsterraNativeBanner` | Wrap Adsterra widgets; used on Sports, Live, News, Special Link | `lib/ads/widgets/lazy_adsterra_strip.dart` |
| `AdListInjector` | List natives also use `LazyAdViewport` | `lib/ads/utils/ad_list_injector.dart` |

### 27.3 APK size policy (rev.8)

| Item | Value |
|------|--------|
| Script targets | `MIN_APK_MB=20`, `MAX_APK_MB=35` |
| Default mode | `BUILD_APK_MODE=split` (32 + 64 APKs) |
| Sideload single file | `BUILD_APK_MODE=arm64 ./tool/build_size_apk.sh` |
| Asset shrink | FIFA banners **PNG → WebP** in `pubspec.yaml` |
| Below 20 MB | Requires feature cuts — see `docs/APK_SIZE_REDUCTION_PLAN.md` (media_kit ~15–20 MB) |

**Build (operator):**

```bash
BUILD_APK_MODE=arm64 ./tool/build_release_apk.sh
ls -lh build/app/outputs/flutter-apk/*.apk
```

**Not measured in this audit:** final APK bytes after local release build (operator-run).

### 27.4 Player performance (branch `hotfix/player-perf-wc`)

| Change | Detail |
|--------|--------|
| Default quality | **540p** mobile; clamp **720p** without Wi‑Fi + battery |
| Android HW decode | **`mediacodec`** forced; avoids MIUI/ColorOS SW fallback |
| Probe / prewarm | Gated to **idle** playback state (less CPU contention) |
| Fit modes | `FittedBox` wrapper for correct stretch/fit (`player_fit_mode.dart`) |

### 27.5 Verification

```bash
flutter test
flutter analyze
BUILD_APK_MODE=arm64 ./tool/build_size_apk.sh   # size QA — run locally
```

---

## SECTION 28 — Forensic P0/P1 Fix Sprint (2026-06-04)

**Context:** Operator-requested fixes from forensic audit checklist (stream token, HTTP cleartext, CAP gate, Appwrite SPOF, ads security).

### 28.1 P0 — Critical (shipped in code)

| ID | Fix | Files |
|----|-----|-------|
| **P0-1** | `StreamTokenService` **direct URL fallback** when `STREAM_TOKEN_BASE_URL` unset or token API network error (uses `originalUrl` + `StreamUrlUpgrade.preferHttps`) | `stream_token_service.dart`, `channel_resolver.dart` |
| **P0-2** | Regenerated cleartext allowlist (**172** stream hosts from full `lib/`); HTTP→HTTPS upgrade with **http-only host denylist** | `tool/gen_network_security_config.py`, `network_security_config.xml`, `stream_url_upgrade.dart` |
| **P0-3** | `build_size_apk.sh` forces `CAP_LOCAL_ONLY_MODE=true` + `LUMIO_SIDELOAD_DEV=true`; clearer `[ServerCap]` logcat hint on missing CAP / invalid JSON | `server_cap.dart`, `build_size_apk.sh` |
| **P0-4** | Appwrite catalog **24h** disk cache TTL; on empty fetch → stale cache + Home **“Using cached channels”** banner | `appwrite_config.dart`, `special_link_cache.dart`, `catalog_service.dart`, `app_provider.dart`, `tv_screen.dart` |

### 28.2 P1 — High (partial)

| ID | Status | Notes |
|----|--------|-------|
| **P1-1** | **Done** | `flutter test` — **183 passed** (2026-06-04); prior “4 failed” not reproduced |
| **P1-2** | **Done** | `MonetagConfig` zones empty by default; `assertReleaseMonetization()` rejects partial Monetag defines |
| **P1-3** | **Done** | CSP meta in `AdsterraHtml`; `WebViewAdHost` blocks `javascript:` / `intent:` / `.apk`; `WebViewAdHost.createController()` for mixed-content hardening |
| **P1-4** | **Deferred** | God-file split (`player_screen` / `app_provider`) — await operator file plan |
| **P1-5** | **Deferred** | Broad `unawaited` audit — low risk paths unchanged |
| **P1-6** | **Partial** | `StreamUrlUpgrade` centralizes HTTPS; full `lib/` http:// sweep not automated |

### 28.3 P2 / P3 — Roadmap (not in this sprint)

| IDs | Topic |
|-----|--------|
| P2-1 | Google UMP / licensed CMP |
| P2-2 | Coin economy server validation |
| P2-3 | Play Integrity token on stream API |
| P2-4 | Production SSL pin hashes + CI defines |
| P2-5 | Player/WebView dispose audit |
| P2-6 | `app-ads.txt` on lumio.app |
| P2-7 | ARB → UI wiring |
| P3-* | WebView pool RC, player auto-quality, background ad pause, analytics depth |

### 28.4 Verification

```bash
flutter test
python3 tool/gen_network_security_config.py
BUILD_APK_MODE=arm64 ./tool/build_size_apk.sh
adb logcat | grep -E 'StreamToken|ServerCap|Appwrite'
```

---

## SECTION 29 — CI/CD Optimization & Appwrite Dual-Config (2026-06-08)

### Focus Areas
This section covers infrastructure improvements between 2026-06-04 and 2026-06-08:
- **Gradle build optimization** for CI reliability
- **Kotlin version alignment** across Flutter plugins
- **Appwrite dual-config** deployment (NYC catalog + SGP Lumio)
- **Featured live events sync** automation
- **Special links integration** (GITUN M3U)

### Gradle Build Optimization

| Item | Detail | Evidence |
|------|--------|----------|
| **JVM heap reduction** | 8GB → 4GB (MaxMetaspaceSize 4GB → 2GB) | `android/gradle.properties:1` |
| **Additional optimizations** | `configureondemand=true`, `welcome=never`, `warning.mode=summary` | `android/gradle.properties:13-15` |
| **Build timeout** | Step-level 75-min timeout added | `.github/workflows/release_apk.yml:94` |
| **Problem solved** | Exit code 143 (SIGTERM) from OOM on CI runners | Git log `c51adc1` |
| **Gradle caching** | Setup Gradle action with caching enabled | `.github/workflows/release_apk.yml:22-25` |

### Kotlin Version Alignment

| Item | Detail | Evidence |
|------|--------|----------|
| **Kotlin version** | **2.1.0** enforced across app + plugins | `android/gradle.properties:23`, `android/settings.gradle.kts` |
| **Plugin patching** | `scripts/patch_plugin_kotlin.sh` patches dynamic plugins | Script enforces 2.1.0 |
| **Metadata mismatch** | Fixed stdlib-common version conflicts | Git log `a639eed`, `4591ffc` |
| **Build flags alignment** | Release workflow flags match release_apk | Git log `a3d33b6` |

### Appwrite Dual-Config Deployment

| Item | Detail | Evidence |
|------|--------|----------|
| **NYC catalog** | Primary channel catalog deployment | `docs/deploy_nyc_catalog.py` |
| **SGP Lumio** | Target Appwrite project for Lumio app | Git log `80ca772` |
| **Split deploy workflow** | Separate workflows for NYC vs SGP targets | `.github/workflows/deploy*.yml` |
| **Featured events sync** | Automated sync of `featured_live_events.json` | Git log `3e8ccd9` |
| **Special links** | GITUN M3U URLs stored in Appwrite special_links | Git log `32fbf2d` |
| **GitunPlaylistService** | New service for GITUN channel parsing | `lib/services/special_link/gitun_playlist_service.dart` |

### New Screens & Services

| New Screen | Purpose | Location |
|------------|---------|----------|
| **BlockedAppsScreen** | Anti-analysis gate (17-package blocklist) | `lib/screens/blocked_apps_screen.dart` |
| **AppOpenPromoScreen** | App-open promo/interstitial display | `lib/screens/app_open_promo_screen.dart` |
| **SpecialLinkHubScreen** | Central hub for special link management | `lib/screens/special_link/special_link_hub_screen.dart` |
| **SpecialLinkListScreen** | GITUN M3U channel list display | `lib/screens/special_link/special_link_list_screen.dart` |

| New Service | Purpose | Location |
|-------------|---------|----------|
| **StreamTokenService** | Stream token resolution with caching | `lib/services/stream_token_service.dart` |
| **GitunPlaylistService** | GITUN M3U parsing and caching | `lib/services/special_link/gitun_playlist_service.dart` |
| **FeaturedLiveEventsService** | Featured events from Appwrite | `lib/services/featured_live_events_service.dart` |

### Ad Injection Improvements

| Item | Detail | Evidence |
|------|--------|----------|
| **List native frequency** | Every 8 channels (down from previous settings) | Git log `0237728` |
| **AdListInjector** | Improved native ad injection in channel lists | `lib/ads/utils/ad_list_injector.dart` |
| **Lazy ad viewport** | Off-screen ad loading suppression | `lib/ads/utils/lazy_ad_viewport.dart` |

### Updated Metrics (2026-06-08)

| Metric | Previous (rev.9) | Current (rev.10) | Change |
|--------|-----------------|-----------------|--------|
| Dart files | 207 | 226 | +19 |
| LOC | ~36,000 | 42,861 | +6,861 |
| Test files | 39 | 67 | +28 |
| Screens | 12 | 16 | +4 |
| Services | 25 | 33 | +8 |

### CI/CD Health

| Item | Status | Notes |
|------|--------|-------|
| **Release APK workflow** | ✅ Optimized | Memory fixes + timeout + Gradle cache |
| **Deploy workflows** | ✅ Split | NYC catalog + SGP Lumio separation |
| **Kotlin alignment** | ✅ Fixed | 2.1.0 across all modules |
| **Missing script guard** | ✅ Added | `publish_apk_appwrite.py` check added |

### Outstanding Items

| Priority | Item | Status |
|----------|------|--------|
| P0 | APK build verification | In progress (workflow #27135235800) |
| P2 | Stream token production host | Not addressed (from §28) |
| P2 | Licensed CMP for tier-1 | Not addressed (from §26) |
| P3 | Play Integrity client attestation | Not addressed (from §26) |

---

## Summary Table

| Section | Score (1–10) | Critical issues |
|---------|--------------|-----------------|
| 1 Project health | **8** | 226 dart files; god files remain; **67 test files** (2026-06-08) |
| 2 Pages / features | **8** | Appwrite catalog; Sports grid-only on All; lazy-ad tabs |
| 3 Ads (4-network) | **9** | Real keys in `secrets.json`; placeholder build guard; valid-config getters |
| 4 Streaming | **8** | Token direct fallback; Appwrite 24h cache; HTTP allowlist expanded |
| 5 Security | **7** | WebView nav filter + CSP; blocked-app gate; Play Integrity server v1.1 |
| 6 Performance | **8** | APK **20–35 MB** policy; lazy ads; `PerformanceTuning` + storage guard |
| 7 Tier-1 | 4 | ARB scaffold; no licensed CMP |
| 8 Acquisition | 7 | Referral scaffold; deep links + FCM |
| 9 Revenue model | 6 | Fill/sideload capped |
| 10 Gaps | — | P0 ops: token API, legal host, CI defines |
| 11 Code quality | **6** | God-file reduced; matcher well-documented in code |
| 12 Verdict | **8** | **85%** sideload launch — fix 4 tests + legal URLs |
| 13 Appwrite | **8** | Main catalog + app_config; Guests Read; no Cloudflare in app |
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
| 24 Product / size / perf | **8** | WebP assets; split APK; Home sliver layout |
| 25 Catalog / APK / ads | **9** | Appwrite channels; split 32/64; ads keys + matcher doc |
| 26 Anti-analysis gate | **8** | 17-package blocklist + Bengali UI; bypassable without server attestation |
| 27 UI density / lazy ads / size | **8** | Tab spacing fix; `LazyAdsterra*`; APK 20–35 MB; player 540p |
| 28 Forensic P0/P1 fixes | **8** | Stream token + cache + CAP + HTTP; P2/P3 roadmap |
| 29 CI/CD & Appwrite dual-config | **9** | Gradle memory fixes; Kotlin 2.1.0; NYC + SGP split; featured events sync |

---

**Report version:** 2026-06-08 **rev.10** (Section 29 CI/CD optimization & Appwrite dual-config; canonical: `AUDIT_REPORT.md`). Mirror: `docs/AUDIT_REPORT_v2.md` — sync header only.

---

*End of audit. Report generated from static analysis only; device fill rates and eCPM require production measurement.*
