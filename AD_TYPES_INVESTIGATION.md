# Lumio IPTV - Complete Ad Types Investigation

## Overview
This document provides a comprehensive investigation of all ad types currently implemented in the Lumio Flutter IPTV app.

---

## Ad Network Providers

### 1. Unity Ads (Direct SDK)
- **Plugin**: unity_ads_plugin ^0.3.30
- **Game ID**: 800000664
- **Implementation**: Direct SDK integration (not mediated)
- **Ad Types**: Rewarded Video Only
- **Usage**: Pre-roll and Mid-roll ad pods
- **Status**: ✅ Recently integrated (current implementation)

### 2. LevelPlay (IronSource Mediation)
- **Plugin**: unity_levelplay_mediation
- **Implementation**: Mediation platform
- **Ad Types**: Banner, Interstitial (mediated)
- **Usage**: Banner ads, mediated interstitials
- **Networks**: Unity Ads, IronSource via mediation

### 3. Adsterra
- **Implementation**: WebView-based + Direct Links
- **Ad Types**: Multiple (see below)
- **Usage**: Various placements throughout app

### 4. Propeller (Monetag)
- **Implementation**: Direct links + Smartlinks
- **Ad Types**: Direct link browser redirects
- **Usage**: Channel tap rotation

---

## Complete Ad Types Inventory

### 🔹 INTERSTITIAL ADS

#### 1. Pre-roll Interstitial (NOW UNITY REWARDED)
- **Location**: Video player before stream starts
- **Type**: Rewarded Video (Unity Ads)
- **Trigger**: User selects channel
- **Cap**: 6 per session (configurable)
- **Cooldown**: 60 seconds between pre-rolls
- **Implementation**: `UnityAdsService.showRewardedAd()`
- **Status**: ✅ Modified to use Unity rewarded only

#### 2. Mid-roll Interstitial (NOW UNITY REWARDED POD)
- **Location**: Video player during playback
- **Type**: Rewarded Video Pod (2 ads)
- **Trigger**: 20-minute interval + 90s watch time
- **Cap**: 4 per session
- **Implementation**: `UnityAdsService.showAdPod()`
- **Status**: ✅ Modified to use Unity rewarded pod

#### 3. Channel Tap Interstitial
- **Location**: External browser
- **Type**: Various networks (rotated)
- **Rotation**: 
  - Adsterra direct link (40%)
  - Monetag/Propeller (30%)
  - LevelPlay mediated A (15%)
  - LevelPlay mediated B (15%)
- **Trigger**: First channel tap per session
- **Implementation**: `ChannelTapAdRotator`
- **Status**: ✅ Active (unchanged)

#### 4. App Open Interstitial
- **Location**: Full-screen promo on app launch
- **Type**: Adsterra WebView or Direct Link
- **Trigger**: App cold start
- **Cap**: Server-side + local caps
- **Implementation**: `AppOpenPromoScreen`
- **Status**: ✅ Active (unchanged)

---

### 🔹 BANNER ADS

#### 1. LevelPlay Banner (Home Bottom)
- **Location**: Bottom of home screen
- **Size**: BANNER (320x50)
- **Network**: LevelPlay (mediated)
- **Refresh**: Auto-refresh (configured in dashboard)
- **Implementation**: `AdBannerWidget`
- **Status**: ✅ Active (unchanged)

#### 2. Adsterra Banner 728
- **Location**: News article list (inline)
- **Size**: 728x90
- **Network**: Adsterra WebView
- **Implementation**: `AdsterraBanner728`
- **Status**: ✅ Active (unchanged)

---

### 🔹 NATIVE ADS

#### 1. In-Feed Native Ads (Channel Lists)
- **Location**: Home, Sports, Live, Categories, Favorites lists
- **Type**: Adsterra Native WebView
- **Interval**: Every 6-8 items (configurable)
- **Implementation**: `AdListInjector.nativeAd()`
- **Status**: ✅ Active (unchanged)

#### 2. News Native Ads
- **Location**: News article list
- **Type**: Adsterra Native WebView
- **Interval**: Every 4 articles
- **Implementation**: `AdPlacementNews.buildArticleList()`
- **Status**: ✅ Active (unchanged)

#### 3. Floating Native Card
- **Location**: Overlay on content
- **Type**: Adsterra Native
- **Implementation**: `FloatingNativeCard`
- **Status**: ✅ Active (unchanged)

#### 4. Sticky Bottom Native
- **Location**: Bottom of screen overlay
- **Type**: Adsterra Native
- **Implementation**: `StickyBottomNative`
- **Status**: ✅ Active (unchanged)

---

### 🔹 SOCIAL BAR ADS

#### 1. Global Social Bar
- **Location**: Above bottom navigation (all tabs)
- **Type**: Adsterra Social Bar WebView
- **Height**: 50px
- **Implementation**: `GlobalSocialBar`
- **Status**: ✅ Active (unchanged)

#### 2. Player Sticky Social Bar
- **Location**: During video playback
- **Type**: Monetag + Adsterra Social
- **Implementation**: Player ad slot
- **Status**: ✅ Active (unchanged)

---

### 🔹 POPUNDER ADS

#### 1. Adsterra Popunder
- **Location**: Hidden 1x1 WebView
- **Type**: Adsterra Popunder Script
- **Trigger**: App background, tab switch
- **Implementation**: `AdsterraPopunderHost`
- **Status**: ✅ Active (unchanged)

---

### 🔹 BACKGROUND ADS

#### 1. Background Ad Engine
- **Location**: Hidden WebView (background)
- **Type**: Adsterra Direct Links Rotation
- **Interval**: Every 60 seconds
- **Cap**: 20 per session
- **Implementation**: `BackgroundAdEngine`
- **Status**: ✅ Active (unchanged)

---

### 🔹 DIRECT LINK ADS

#### 1. Channel Tap Direct Link
- **Location**: External browser
- **Type**: Adsterra Direct Link
- **Trigger**: Channel tap (rotation)
- **Implementation**: `AdsterraEngine.openChannelTapBrowser()`
- **Status**: ✅ Active (unchanged)

#### 2. News Article Direct Link
- **Location**: External browser
- **Type**: Adsterra Direct Link
- **Trigger**: First news article tap
- **Implementation**: `AdsterraEngine.openNewsArticleBrowser()`
- **Status**: ✅ Active (unchanged)

#### 3. Monetag Smartlink
- **Location**: External browser
- **Type**: Propeller/Monetag Smartlink
- **Trigger**: Various (rotated)
- **Implementation**: `PropellerService`
- **Status**: ✅ Active (unchanged)

---

### 🔹 VIDEO PLAYER ADS

#### 1. Pause Overlay Ad
- **Location**: Video player pause screen
- **Type**: Adsterra WebView overlay
- **Trigger**: Video pause (>2 min playback)
- **Implementation**: Player overlay
- **Status**: ✅ Active (unchanged)

#### 2. Player Ad Slot
- **Location**: Video player container
- **Type**: Monetag in-page push
- **Implementation**: `PlayerAdSlot`
- **Status**: ✅ Active (unchanged)

#### 3. Player Overlay Ad
- **Location**: Video player overlay
- **Type**: Adsterra WebView
- **Implementation**: `PlayerOverlayAd`
- **Status**: ✅ Active (unchanged)

---

### 🔹 PUSH NOTIFICATION ADS

#### 1. Monetag Push
- **Location**: System push notifications
- **Type**: Monetag push subscription
- **Trigger**: App first launch
- **Implementation**: `MonetagPushService`
- **Status**: ✅ Active (unchanged)

---

## Ad Placement Locations

| Location | Ad Type | Network | Status |
|----------|---------|---------|---------|
| Home Screen | Banner | LevelPlay | ✅ Active |
| Home List | Native | Adsterra | ✅ Active |
| Sports List | Native | Adsterra | ✅ Active |
| Live List | Native | Adsterra | ✅ Active |
| News List | Native + Banner | Adsterra | ✅ Active |
| Categories List | Native | Adsterra | ✅ Active |
| Favorites List | Native | Adsterra | ✅ Active |
| Global (Bottom Nav) | Social Bar | Adsterra | ✅ Active |
| Channel Tap | Interstitial/Direct | Rotated | ✅ Active |
| Video Player (Pre-roll) | Rewarded | Unity Ads | ✅ Modified |
| Video Player (Mid-roll) | Rewarded Pod | Unity Ads | ✅ Modified |
| Video Player (Pause) | Overlay | Adsterra | ✅ Active |
| Video Player (Slot) | In-page Push | Monetag | ✅ Active |
| App Open | Interstitial | Adsterra | ✅ Active |
| Background | Hidden WebView | Adsterra | ✅ Active |
| News Article Tap | Direct Link | Adsterra | ✅ Active |

---

## Ad Trigger Mechanisms

### User-Initiated Triggers
- Channel tap
- News article tap
- Back button press (exit intent)
- App open

### Time-Based Triggers
- App open (cold start)
- 20-minute intervals (mid-roll)
- 60-second rotation (background)
- Timer-based cooldowns

### State-Based Triggers
- Video pause
- App background
- Tab switch
- Orientation change

---

## Ad Cap & Cooldown System

### Session Caps
- Pre-roll: 6 per session
- Mid-roll: 4 per session
- Background: 20 per session
- Channel tap: Per-channel limits

### Time-Based Cooldowns
- Pre-roll: 60 seconds
- Popunder: 0-240 seconds (by trigger)
- Direct link: 5 seconds minimum

### Server-Side Caps
- CAP_BASE_URL + HMAC_KEY authentication
- Fallback to local caps if server unavailable

---

## Analytics Events

### Current Analytics Events
- `interstitial_shown` (LevelPlay)
- `rewarded_shown` (LevelPlay)
- `rewarded_complete` (LevelPlay)
- `ad_interstitial_shown` (Unity, Adsterra)
- `ad_interstitial_skipped_cap`
- `ad_interstitial_failed`
- `banner_impression` (LevelPlay)
- `adsterra_native_loaded`
- `adsterra_banner_loaded`
- `channel_tap_slot`
- `lumio_ad_impression`
- `lumio_ad_click`
- `ad_fill_rate`
- `ad_waterfall_attempt`
- `ad_waterfall_fallback`
- `ad_waterfall_failure`
- `cap_client_fallback`

### New Unity Events (Recently Added)
- `unity_ad_loaded`
- `unity_ad_shown`
- `unity_ad_completed`
- `unity_ad_skipped`
- `unity_ad_failed`
- `unity_ad_pod_started`
- `unity_ad_pod_completed`
- `unity_ad_pod_partial`
- `pre_roll_ad_started`
- `pre_roll_ad_completed`
- `pre_roll_ad_skipped`
- `pre_roll_ad_failed`
- `ad_interval_reached`
- `stream_resumed_after_ad`

---

## Summary

### Total Ad Types: 15+
1. Pre-roll Rewarded (Unity Ads)
2. Mid-roll Rewarded Pod (Unity Ads)
3. Channel Tap Interstitial (Rotated)
4. App Open Interstitial (Adsterra)
5. LevelPlay Banner
6. Adsterra Banner 728
7. In-Feed Native Ads
8. News Native Ads
9. Floating Native Card
10. Sticky Bottom Native
11. Global Social Bar
12. Player Sticky Social Bar
13. Adsterra Popunder
14. Background Ad Engine
15. Direct Link Ads
16. Pause Overlay Ad
17. Player Ad Slot
18. Player Overlay Ad
19. Monetag Push

### Ad Networks Used
1. **Unity Ads** - Rewarded video only (pre-roll, mid-roll)
2. **LevelPlay** - Banner, mediated interstitial
3. **Adsterra** - Native, banner, social bar, popunder, direct links
4. **Monetag/Propeller** - Smartlinks, push notifications, direct links

### Recent Changes
✅ **Only Modified**: Pre-roll and Mid-roll ad systems
- Changed from: LevelPlay mediated interstitial
- Changed to: Unity Ads rewarded video (direct SDK)
- All other ad types remain **unchanged**

### What Was NOT Touched
❌ Banner ads (LevelPlay, Adsterra)
❌ Native ads (all placements)
❌ Social bar (global, player)
❌ Popunder ads
❌ Background ad engine
❌ Channel tap rotation
❌ App open interstitial
❌ Direct link ads
❌ Push notifications
❌ Pause overlay ads
❌ Player ad slots

---

## Configuration Files

### Ad Config Constants
- `lib/config/ad_config.dart` - Main ad configuration
- `lib/config/ad_policy_config.dart` - Remote config policies
- `lib/config/monetag_config.dart` - Monetag configuration

### Ad Managers
- `lib/ads/ad_manager.dart` - Global ad orchestration
- `lib/ads/ad_trigger_manager.dart` - Caps and triggers
- `lib/ads/ad_placement_config.dart` - Placement rules

### Ad Services
- `lib/services/unity_ads_service.dart` - Unity Ads SDK
- `lib/services/adsterra_webview_service.dart` - Adsterra WebView
- `lib/services/ad_safety_service.dart` - Safety gates
- `lib/services/ad_consent_service.dart` - GDPR consent

---

## Conclusion

The Lumio IPTV app has a comprehensive multi-network ad system with **15+ different ad types** across **4 major ad networks**. The recent Unity Ads integration **only modified the pre-roll and mid-roll systems** to use rewarded videos, while all other ad types (banner, native, social bar, popunder, background, etc.) remain **completely unchanged** and continue to function as before.