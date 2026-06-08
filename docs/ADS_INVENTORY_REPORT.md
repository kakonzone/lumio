# Lumio App - Complete Ads Inventory Report

**Report Date:** 2026-06-08  
**App Version:** 1.0.0+1  
**Scope:** Full codebase scan for ad integration analysis

---

═══════════════════════════════════════════
1. AD SDK INVENTORY
═══════════════════════════════════════════

## Integrated Ad Packages (pubspec.yaml)

| Package | Version | Purpose | File Location |
|---------|---------|---------|---------------|
| **unity_levelplay_mediation** | 9.2.0 | Unity Ads via LevelPlay mediation (primary SDK) | pubspec.yaml:59 |
| **webview_flutter** | 4.13.1 | Adsterra WebView ads (banner/native/social) | pubspec.yaml:60 |
| **webview_flutter_android** | 4.12.0 | Android WebView for ad rendering | pubspec.yaml:61 |
| **firebase_messaging** | 16.2.2 | Push notifications (match alerts) | pubspec.yaml:51 |
| **firebase_analytics** | 12.4.1 | Ad analytics tracking | pubspec.yaml:53 |

## AndroidManifest.xml Ad SDK Configuration

| SDK | Configuration | Value/Location | File Reference |
|-----|--------------|---------------|----------------|
| **ironSource (LevelPlay)** | Application Key | `@string/levelplay_app_key` (from dart-define) | AndroidManifest.xml:136-137 |
| **Monetag** | Push Channel | `lumio.monetag_push.channel = lumio_monetag_push` | AndroidManifest.xml:140-142 |
| **Advertising ID** | Permission | `com.google.android.gms.permission.AD_ID` | AndroidManifest.xml:21 |
| **WiFi State** | Permission | `android.permission.ACCESS_WIFI_STATE` (mediation classification) | AndroidManifest.xml:15 |

## Ad Networks Summary
- **Primary:** ironSource/LevelPlay (with Unity Ads mediation)
- **Secondary:** Adsterra (WebView-based: banner, native, popunder, social bar, direct link)
- **Tertiary:** Monetag/Propeller (onclick, vignette, push, in-page push, direct link)
- **Analytics:** Firebase Analytics + custom Adsterra telemetry

---

═══════════════════════════════════════════
2. SCREEN-BY-SCREEN AD PLACEMENT
═══════════════════════════════════════════

## 📱 Splash Screen
- **Ad Type:** None (consent popup removed - see commit 374ab2f)
- **Interstitial:** App-open substitute after splash (configurable)
- **Network:** LevelPlay (via AdTriggerManager)
- **File Location:** lib/screens/splash_screen.dart
- **Trigger Condition:** Post-splash, after branding delay (configurable via `splashMinMsBeforeAds`)
- **Special Features:** 
  - AdManager preload from splash
  - Background engine scheduling

## 📱 Home Screen (TvScreen)
- **Banner Ad:** Yes, Adsterra 728x90 bottom
- **Network:** Adsterra
- **Position:** Bottom of home feed
- **File Location:** lib/screens/tv_screen.dart:669-670
- **Placement:** `home_bottom_banner`
- **Native Ad:** Yes, Adsterra native banner
- **Position:** Top of channel list (after promo carousel)
- **File Location:** lib/screens/tv_screen.dart:503-506
- **Placement:** `home_native_top`
- **Frequency:** Every 8 channels (AdListInjector)
- **Floating Native:** Yes
- **Placement:** `home_floating_native`
- **File Location:** lib/screens/tv_screen.dart:102
- **Interstitial Trigger:** Post-splash, channel tap, back press
- **File Reference:** lib/screens/tv_screen.dart (AdManager integration)

## 📱 Sports Screen
- **Banner Ad:** Yes, Adsterra 728x90 top
- **Network:** Adsterra
- **Position:** Above category grid
- **File Location:** lib/screens/other_screens.dart:266
- **Placement:** `sports_top`
- **Native Ad:** Yes, Adsterra native in channel list
- **Position:** Injected every 8 channels
- **File Location:** lib/screens/other_screens.dart:396
- **Floating Native:** Yes
- **Placement:** `sports_floating_native`
- **File Location:** lib/screens/other_screens.dart:216
- **Interstitial Trigger:** Channel tap, navigation

## 📱 Live Screen
- **Banner Ad:** Yes, Adsterra 728x90 top
- **Network:** Adsterra
- **Position:** Above live events list
- **File Location:** lib/screens/other_screens.dart:626
- **Placement:** `live_top`
- **Native Ad:** Yes, Adsterra native in channel list
- **Position:** Injected every 8 channels
- **File Location:** lib/screens/other_screens.dart:719 (via AdListInjector)
- **Interstitial Trigger:** Channel tap, navigation

## 📱 News Screen
- **Banner Ad:** Yes, Adsterra 728x90
- **Network:** Adsterra
- **Position:** Below category navigation (sticky)
- **File Location:** lib/screens/news_screen.dart (LazyAdsterraBanner728)
- **Placement:** `news_headlines`
- **Native Ad:** Yes, Adsterra native in article list
- **Position:** Every 5 articles (news-specific density)
- **File Location:** lib/ads/ad_placement_news.dart
- **Placement:** `news_native_list`
- **Frequency:** Every 5 articles (aggressive: every 4)

## 📱 Categories Screen
- **Banner Ad:** Yes, Adsterra 728x90
- **Network:** Adsterra
- **Position:** Above category grid
- **File Location:** lib/screens/other_screens.dart (LazyAdsterraBanner728)
- **Placement:** `categories_top`
- **Native Ad:** Yes, Adsterra native in channel list
- **Position:** Every 8 channels
- **File Location:** lib/screens/other_screens.dart (AdListInjector)
- **Interstitial Trigger:** Category tap, navigation

## 📱 Category Drill-down Screen
- **Banner Ad:** Yes, Adsterra 728x90
- **Network:** Adsterra
- **Position:** Top of channel list
- **File Location:** lib/screens/category_channels_screen.dart (LazyAdsterraBanner728)
- **Placement:** `category_drilldown_top`
- **Native Ad:** Yes, Adsterra native in channel list
- **Position:** Every 8 channels
- **File Location:** lib/screens/category_channels_screen.dart (AdListInjector)
- **Interstitial Trigger:** Channel tap

## 📱 Favorites Screen
- **Banner Ad:** Yes, Adsterra 728x90
- **Network:** Adsterra
- **Position:** Top of favorites list
- **File Location:** lib/screens/favorites_screen.dart (LazyAdsterraBanner728)
- **Placement:** `favorites_top`
- **Native Ad:** Yes, Adsterra native in channel list
- **Position:** Every 8 channels
- **File Location:** lib/screens/favorites_screen.dart (AdListInjector)
- **Interstitial Trigger:** Channel tap

## 📱 Special Link Screen (GITUN)
- **Banner Ad:** Yes, Adsterra 728x90
- **Network:** Adsterra
- **Position:** Top of special link list
- **File Location:** lib/screens/special_link/special_link_list_screen.dart:90
- **Placement:** `special_link_top`
- **Native Ad:** Yes, Adsterra native in channel list
- **Position:** Every 8 channels
- **File Location:** lib/screens/special_link/special_link_list_screen.dart (AdListInjector)
- **Interstitial Trigger:** Channel tap

## 📱 Player Screen (Channel Tap / Playback)
- **Pre-roll Ad:** Yes, LevelPlay/Adsterra waterfall
- **Network:** LevelPlay (primary) → Adsterra (fallback)
- **Trigger:** Before video playback starts
- **File Location:** lib/screens/player/player_overlay.dart:38-42
- **Placement:** `InterstitialPlacement.preroll`
- **Frequency:** Max 6 per session, 1 per channel key per session
- **Browser Redirect:** Yes, Adsterra direct link on channel tap
- **Network:** Adsterra (random rotation from bundle)
- **File Location:** lib/ads/strategies/channel_tap_ad_rotator.dart
- **Trigger:** First channel tap (cooldown: 5 seconds)
- **Banner During Playback:** Yes, Adsterra native (pause overlay)
- **Network:** Adsterra
- **Position:** Pause overlay (110px height)
- **File Location:** lib/screens/player/player_controls_bar.dart:380
- **Placement:** `pause_overlay`
- **Mid-roll Ad:** Yes, LevelPlay/Adsterra waterfall
- **Network:** LevelPlay (primary) → Adsterra (fallback)
- **Trigger:** Periodic during playback (configurable period)
- **File Location:** lib/screens/player/player_overlay.dart:47-53, 68-79
- **Placement:** Mid-roll interstitial
- **Frequency:** Max 4 per session, minimum 90 seconds between channel switches
- **In-Page Push:** Yes, Monetag sticky during playback
- **Network:** Monetag
- **Position:** Sticky WebView overlay
- **File Location:** lib/screens/player/player_controls_bar.dart:371
- **Zone:** `MONETAG_INPAGE_ZONE`
- **Visibility:** Configurable via `PLAYER_ADS_USER_VISIBLE` (default: hidden opacity 0)

## 📱 Settings / Drawer
- **Ad Placement:** "Ads & privacy" menu option (no ads on this screen)
- **File Location:** lib/widgets/app_drawer.dart:392-395
- **Purpose:** Legal links + ad-free rewards (watch rewarded video)
- **Rewarded Ad:** Yes, LevelPlay rewarded video
- **Network:** LevelPlay
- **Purpose:** Earn 60 minutes ad-free time
- **File Location:** lib/screens/ads_privacy_screen.dart:127-150

## 📱 App Open Promo Screen
- **Ad Type:** Optional promotional overlay
- **Network:** None (promo content)
- **File Location:** lib/screens/app_open_promo_screen.dart
- **Trigger:** After home visible, 900ms defer
- **Countdown:** 3 seconds (skip instant)

## 📱 Global Ad Chrome
- **Social Bar:** Yes, Adsterra social bar on all main tabs
- **Network:** Adsterra
- **Position:** Sticky bottom bar
- **File Location:** lib/ads/widgets/global_social_bar.dart
- **Enabled:** `globalSocialBarEnabled = true`
- **Refresh:** 20 seconds

---

═══════════════════════════════════════════
3. AD FREQUENCY & CAPS
═══════════════════════════════════════════

## Per-Device/Session Caps (lib/config/ad_config.dart:293-304)

| Ad Type | Cap | Time Window | File Reference |
|---------|-----|-------------|----------------|
| **Rewarded Video** | 5 per hour | 1 hour | ad_config.dart:293 |
| **Interstitial (LevelPlay)** | 14 per hour | 1 hour | ad_config.dart:295 |
| **Interstitial Cooldown** | 35 seconds minimum | Between shows | ad_config.dart:296 |
| **App Open Substitute** | 5 per day | 24 hours | ad_config.dart:297 |
| **App Open Cooldown** | 2 hours minimum | Between app opens | ad_config.dart:298 |
| **Adsterra Direct Link** | 3 per day | 24 hours | ad_config.dart:299 |
| **Adsterra Popunder** | 2 per session | Per session | ad_config.dart:300 |
| **Adsterra Popunder Cooldown** | 90 seconds | Between shows | ad_config.dart:301 |
| **Network Isolation** | 30 seconds | LevelPlay after Adsterra | ad_config.dart:303 |
| **Session Interstitial Max** | 14 per session | Per session | ad_config.dart:331 |
| **Pre-roll Max** | 6 per session | Per session | ad_config.dart:334 |
| **Pre-roll Popunder Cooldown** | 60 seconds | After pre-roll | ad_config.dart:335 |
| **Mid-roll Max** | 4 per session | Per session | ad_config.dart:338 |
| **Mid-roll Channel Cooldown** | 90 seconds minimum | Between channels | ad_config.dart:339 |
| **Channel Clicks Before Interstitial** | Configurable (remote) | Per session | ad_config.dart:342 |

## Refresh Rates

| Ad Type | Refresh Rate | File Reference |
|---------|-------------|----------------|
| **LevelPlay Banner** | 60 seconds | ad_config.dart:397 (dashboard setting) |
| **Adsterra Sticky WebView** | 20 seconds | ad_config.dart:400 |
| **Native List (General)** | Every 8 channels | ad_config.dart:401 |
| **Native List (News)** | Every 5 channels | ad_config.dart:403 |
| **Native List (Aggressive)** | Every 4 channels | ad_config.dart:404 |
| **Background Ad Rotation** | 60 seconds | ad_config.dart:360 |
| **Background Ad Session Cap** | 40 per session | ad_config.dart:361 |

## Popunder Cooldowns by Trigger

| Trigger | Cooldown (seconds) | File Reference |
|---------|-------------------|----------------|
| **Post-splash** | 8 seconds | ad_config.dart:384 |
| **Tab switch** | 240 seconds (4 min) | ad_config.dart:385 |
| **Player close** | 0 seconds | ad_config.dart:386 |
| **Home back** | 0 seconds | ad_config.dart:387 |
| **First click reset** | 24 hours | ad_config.dart:389 |
| **Channel tap ad minimum** | 5 seconds | ad_config.dart:390 |

---

═══════════════════════════════════════════
4. AD TRIGGERS & EVENTS
═══════════════════════════════════════════

## App Open Triggers
- **Cold Start:** AdManager.preloadFromSplash() (loads LevelPlay)
- **Post-splash:** App-open substitute interstitial (if cap allows)
- **Splash Delay:** `splashMinMsBeforeAds` (400ms local caps, 2500ms server caps)
- **App Open Promo:** Optional overlay after home visible (900ms defer)
- **Push Subscription:** One-time WebView on first home load (Monetag)

## Navigation Triggers
- **Channel Tap:** 
  - First tap: Adsterra direct link browser redirect (5s cooldown)
  - Subsequent taps: Pre-roll interstitial (if cap allows)
- **Tab Switch:** Popunder/overlay (240s cooldown)
- **Back Press:** Home back popunder (0s cooldown)
- **Screen Load:** Banner/native ads load on each screen

## Player Triggers
- **Pre-roll:** Before video playback (max 6/session, 1/channel key)
- **Pause Overlay:** Adsterra native banner on pause (110px height)
- **Mid-roll:** Periodic interstitial during playback (max 4/session, 90s channel cooldown)
- **Player Close:** Popunder/overlay (0s cooldown)
- **In-Page Push:** Sticky Monetag WebView during playback

## Custom Triggers
- **Time-based:** Background ad rotation every 60 seconds
- **Action-based:** Channel tap, tab switch, player events
- **Scroll-based:** Lazy ad viewport (off-screen ads not loaded)
- **Session-based:** Per-session caps for all ad types

## Exit Intent
- **Exit Interstitial:** Yes, via ExitIntentHandler
- **Trigger:** Back press, app minimize
- **Network:** LevelPlay/Adsterra waterfall
- **File Location:** lib/ads/exit_intent_handler.dart

---

═══════════════════════════════════════════
5. AD NETWORK PRIORITY / WATERFALL
═══════════════════════════════════════════

## Mediation Setup
- **Primary:** LevelPlay (ironSource) with Unity Ads mediation
- **Configuration:** Unity Ads configured in LevelPlay dashboard (no Unity SDK in app)
- **Note:** "Unity Ads → LevelPlay dashboard mediation only" (ad_config.dart:144-145)

## Waterfall Configuration
- **Strategy:** LevelPlay (primary) → Adsterra (fallback/aggressive)
- **Timeout:** 3 seconds per network attempt
- **Skip Threshold:** Skip network after 3 load/show failures per session
- **Network Isolation:** 30-second LevelPlay cooldown after Adsterra popunder/background
- **File Location:** lib/ads/ad_waterfall.dart

## Per-Ad-Type Network Usage

| Ad Type | Primary Network | Fallback Network | File Reference |
|---------|----------------|------------------|----------------|
| **Interstitial** | LevelPlay | Adsterra (waterfall) | ad_waterfall.dart |
| **Banner (728x90)** | Adsterra | None (WebView only) | adsterra_banner.dart |
| **Native Banner** | Adsterra | None (WebView only) | adsterra_native.dart |
| **Popunder** | Adsterra | None (script injection) | adsterra_popunder.dart |
| **Social Bar** | Adsterra | None (WebView only) | adsterra_social_bar.dart |
| **Direct Link** | Adsterra | Monetag (onclick) | channel_tap_ad_rotator.dart |
| **Rewarded Video** | LevelPlay | None (native SDK) | ironsource_service.dart |
| **In-Page Push** | Monetag | None (WebView) | propeller_engine.dart |

## Remote Control
- **Network Toggle:** Appwrite global_config (levelplayEnabled, adsterraEnabled, monetagEnabled)
- **Aggressive Mode:** Remote flag for increased frequency
- **Banner Toggle:** Remote bannerEnabled flag
- **Popunder Toggle:** Remote popunderEnabled flag
- **File Location:** lib/config/ad_config.dart:306-325

---

═══════════════════════════════════════════
6. AD UNIT IDs / ZONE IDs
═══════════════════════════════════════════

## LevelPlay (ironSource) Configuration

| Unit Type | Dart-Define Key | Status | File Reference |
|-----------|----------------|--------|----------------|
| **App Key** | `LEVELPLAY_APP_KEY` | Required (dart-define) | ad_config.dart:81-83 |
| **Interstitial Unit** | `LEVELPLAY_INTERSTITIAL_AD_UNIT` | Required (dart-define) | ad_config.dart:84-86 |
| **Banner Unit** | `LEVELPLAY_BANNER_AD_UNIT` | Required (dart-define) | ad_config.dart:87-89 |
| **Rewarded Unit** | `LEVELPLAY_REWARDED_AD_UNIT` | Optional (dart-define) | ad_config.dart:90-92 |

**AndroidManifest:** `<meta-data android:name="com.ironsource.sdk.ApplicationKey" android:value="@string/levelplay_app_key" />`

## Adsterra Zone IDs (WebView-based)

| Zone Type | Dart-Define Key | Status | File Reference |
|-----------|----------------|--------|----------------|
| **Direct Link** | `ADSTERRA_DIRECT_LINK` | Optional (dart-define) | ad_config.dart:148-150 |
| **Direct Links Bundle** | `ADSTERRA_DIRECT_LINKS` | Optional (pipe-separated) | ad_config.dart:153-155 |
| **Smartlink URL** | `ADSTERRA_SMARTLINK_URL` | Optional (dart-define) | ad_config.dart:184-186 |
| **Smartlinks Bundle** | `ADSTERRA_SMARTLINKS` | Optional (pipe-separated) | ad_config.dart:189-191 |
| **Popunder Script** | `ADSTERRA_POPUNDER_SCRIPT_URL` | Optional (dart-define) | ad_config.dart:221-223 |
| **Popunder Base URL** | `ADSTERRA_POPUNDER_BASE_URL` | Optional (dart-define) | ad_config.dart:224-226 |
| **Native Invoke URL** | `ADSTERRA_NATIVE_INVOKE_URL` | Optional (dart-define) | ad_config.dart:227-229 |
| **Native Container ID** | `ADSTERRA_NATIVE_CONTAINER_ID` | Optional (dart-define) | ad_config.dart:230-232 |
| **Native Base URL** | `ADSTERRA_NATIVE_BASE_URL` | Optional (dart-define) | ad_config.dart:233-235 |
| **Social Script URL** | `ADSTERRA_SOCIAL_SCRIPT_URL` | Optional (dart-define) | ad_config.dart:236-238 |
| **Social Base URL** | `ADSTERRA_SOCIAL_BASE_URL` | Optional (dart-define) | ad_config.dart:239-241 |
| **Banner 728 Invoke URL** | `ADSTERRA_BANNER728_INVOKE_URL` | Optional (dart-define) | ad_config.dart:242-244 |
| **Banner 728 Container ID** | `ADSTERRA_BANNER728_CONTAINER_ID` | Optional (dart-define) | ad_config.dart:245-247 |
| **Banner 728 Base URL** | `ADSTERRA_BANNER728_BASE_URL` | Optional (dart-define) | ad_config.dart:248-250 |

## Monetag Zone IDs (PropellerAds)

| Zone Type | Dart-Define Key | Status | File Reference |
|-----------|----------------|--------|----------------|
| **Onclick (Native)** | `MONETAG_ONCLICK_ZONE` | Required if configured | monetag_config.dart:11 |
| **Vignette (Interstitial)** | `MONETAG_VIGNETTE_ZONE` | Required if configured | monetag_config.dart:12 |
| **Push (Banner)** | `MONETAG_PUSH_ZONE` | Required if configured | monetag_config.dart:13 |
| **In-Page Push** | `MONETAG_INPAGE_ZONE` | Required if configured | monetag_config.dart:14 |
| **Direct Link** | `MONETAG_DIRECT_ZONE` | Required if configured | monetag_config.dart:15 |
| **Onclick Script Host** | `MONETAG_ONCLICK_HOST` | Required if configured | monetag_config.dart:39 |
| **Vignette Script Host** | `MONETAG_VIGNETTE_HOST` | Required if configured | monetag_config.dart:40 |
| **Push Script URL** | `MONETAG_PUSH_SCRIPT` | Required if configured | monetag_config.dart:41 |
| **In-Page Push Host** | `MONETAG_INPAGE_HOST` | Required if configured | monetag_config.dart:42 |
| **Direct Link URL** | `MONETAG_DIRECT_LINK` | Required if configured | monetag_config.dart:43 |

**Release Requirement:** If any Monetag key is set, ALL must be set (no hardcoded fallbacks)

## Hardcoded vs Remote Config
- **LevelPlay:** All IDs via dart-define (build-time)
- **Adsterra:** All zones via dart-define (build-time)
- **Monetag:** All zones via dart-define (build-time)
- **Remote Control:** Enable/disable flags via Appwrite global_config
- **Placeholder Detection:** Built-in validation for example.com/placeholder URLs

---

═══════════════════════════════════════════
7. PROBLEM AREAS
═══════════════════════════════════════════

## Missing Ad Placements (Should Be Present)

| Screen | Current Status | Recommendation |
|--------|----------------|----------------|
| **Splash Screen** | No ad (consent removed) | Consider app-open interstitial |
| **Search Screen** | No ad found | Add banner/native for monetization |
| **Video Player Exit** | No exit ad after playback ends | Add post-roll interstitial |
| **Error Screens** | No ad found | Monetize error states |
| **Loading Screens** | Limited ads | Add more loading monetization |

## Over-Ad-Load Areas

| Area | Current Behavior | User Impact |
|------|----------------|-------------|
| **Home Screen** | Native + banner + floating native | High ad density |
| **Player Pause** | Native banner overlay + in-page push (hidden) | May confuse users |
| **Channel Tap** | Browser redirect + pre-roll | Double ad exposure |
| **Tab Switch** | Popunder/overlay (240s cooldown) | Frequent interruptions |
| **Background Engine** | Silent rotation every 60s (40/session cap) | Background resource usage |

## Auto-Redirect Locations

| Location | Behavior | Network | File Reference |
|----------|----------|---------|----------------|
| **Channel Tap (First)** | Browser redirect to Adsterra direct link | Adsterra | channel_tap_ad_rotator.dart |
| **Direct Link Rotation** | Random pick from bundle (pipe-separated) | Adsterra | ad_config.dart:157-170 |
| **Smartlink Rotation** | Random pick from smartlink bundle | Adsterra | ad_config.dart:198-211 |
| **Background Engine** | Silent headless WebView rotation | Adsterra | background_ad_engine.dart |

## Missing Frequency Caps

| Area | Current Status | Risk |
|------|----------------|------|
| **Native Ad Injection** | Every 8 channels (fixed) | May be too aggressive for small lists |
| **Banner Refresh** | 60s LevelPlay, 20s Adsterra | Might be too frequent |
| **Popunder Cooldown** | 90s, but 0s on some triggers | Inconsistent UX |
| **Direct Link Cooldown** | 5 seconds per tap | Might be too short |

## Technical Issues

| Issue | Location | Impact |
|-------|----------|--------|
| **Placeholder Detection** | ad_config.dart:101-118 | Build-time validation only, no runtime |
| **Network Failure Skip** | ad_config.dart:357 | Skip after 3 failures (might be too aggressive) |
| **WebView Pool** | webview_pool.dart | Resource management unclear |
| **Player Ads Visibility** | ad_config.dart:377-380 | Default hidden (opacity 0) - revenue loss |
| **Consent Removal** | splash_screen.dart | Removed consent popup (GDPR risk for tier-1) |

---

═══════════════════════════════════════════
8. RECOMMENDATIONS
═══════════════════════════════════════════

## Income Boost Opportunities

| Opportunity | Implementation | Expected Impact |
|-------------|----------------|-----------------|
| **Splash Interstitial** | Add app-open interstitial after consent | +15-20% revenue |
| **Search Ads** | Add banner/native to search screen | +5-10% revenue |
| **Post-Roll Ad** | Add interstitial after video ends | +10-15% revenue |
| **Error Screen Ads** | Monetize loading/error states | +3-5% revenue |
| **Rewarded Interstitial** | Add rewarded option for extra content | +8-12% revenue |
| **Player Ads Visibility** | Enable PLAYER_ADS_USER_VISIBLE=true | +20-30% player revenue |

## Ad Type Optimization

| Current Action | Recommendation | Reason |
|----------------|----------------|--------|
| **Player ads hidden** | Enable visible in-page push | Hidden ads = no revenue |
| **Native frequency (8)** | Increase to 12 for larger lists | More inventory |
| **Banner refresh (20s)** | Increase to 30s | Better UX, similar fill |
| **Popunder (0s cooldown)** | Add minimum 30s cooldown | Consistent UX |
| **Direct link (5s)** | Increase to 10s cooldown | Better UX |

## Mediation Optimization

| Action | Implementation | Benefit |
|--------|----------------|---------|
| **Add AdMob** | Configure as fallback network | Higher fill rate |
| **Add AppLovin** | Configure as secondary network | Competition increases CPM |
| **Geo-Based Zones** | Use different zones by country | Higher regional CPM |
| **A/B Testing** | Test different ad densities | Optimize for revenue |
| **Header Bidding** | Implement if available | Higher CPM |

## Technical Improvements

| Area | Recommendation | File Location |
|------|----------------|----------------|
| **Runtime Validation** | Add runtime placeholder check | ad_config.dart |
| **Failure Retry Logic** | Add exponential backoff | ad_waterfall.dart |
| **WebView Pool Limits** | Add max pool size | webview_pool.dart |
| **Analytics** | Add detailed impression logging | ad_analytics.dart |
| **Error Handling** | Add graceful degradation | ad_manager.dart |

## Geo-Based Custom Zones (Suggestion)

| Region | Ad Network Strategy | Zone Configuration |
|--------|-------------------|-------------------|
| **BD/PK/IN** | Adsterra + LevelPlay (local focus) | Higher direct link frequency |
| **US/UK/EU** | LevelPlay + AdMob (compliance) | GDPR-compliant zones |
| **Tier-3 Countries** | Aggressive Adsterra + Monetag | Max popunder frequency |
| **VPN Detected** | Monetag-only (anti-fraud) | Special VPN zones |

## Compliance & UX

| Area | Current State | Recommendation |
|------|--------------|----------------|
| **GDPR** | Consent removed | Add compliant CMP for tier-1 |
| **Play Store** | Sideload-only (no store) | If targeting store, add compliance |
| **Ad Load** | High density | Add user feedback mechanism |
| **Performance** | Background rotation | Monitor battery/memory impact |
| **Analytics** | Firebase + custom | Add revenue tracking |

## Priority Implementation Order

1. **Immediate (Revenue):** Enable player ads visibility, add splash interstitial
2. **Short-term (UX):** Increase native frequency, add post-roll ads
3. **Medium-term (Tech):** Runtime validation, failure retry logic
4. **Long-term (Growth):** Add AdMob/AppLovin mediation, geo-based zones

---

**Report End**

*This report is based on static code analysis. Actual revenue performance requires production measurement and A/B testing.*
