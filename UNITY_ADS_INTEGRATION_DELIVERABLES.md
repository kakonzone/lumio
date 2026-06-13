# Unity Ads Integration - Deliverables Documentation

## Overview
This document outlines the Unity Ads rewarded video integration for the Lumio Flutter IPTV app. All ads are now **REWARDED ONLY** - no interstitials, banners, or other ad types.

## Unity Ads Credentials
- **Game ID (Android)**: 800000664
- **Organization Core ID**: 18968439096061
- **Placement Name**: Rewarded_Video
- **Placement ID**: Rewarded_Android
- **Test Mode**: false (production)

---

## Modified Files

### 1. android/app/src/main/AndroidManifest.xml
**Reason**: Added Unity Ads Game ID metadata
**Changes**: Added meta-data tag for Unity Ads Game ID (800000664)

### 2. lib/config/ad_config.dart
**Reason**: Added Unity Ads rewarded video configuration constants
**Changes**: 
- Added `midRollAdType = "unity_rewarded"`
- Added `unityRewardedPlacement = "Rewarded_Android"`
- Added `skipDelaySeconds = 15`
- Added `adsPerPod = 2`

### 3. lib/services/unity_ads_service.dart
**Reason**: Enhanced Unity Ads service with ad pod functionality
**Changes**:
- Added ad pod state management (`_adPodInProgress`, `_currentAdIndex`, `_adStartTime`)
- Added `isAdReady` getter
- Added `_preloadNext()` method for background preloading
- Added `showRewardedAd()` with callbacks (onComplete, onSkip, onFail)
- Added `showAdPod()` for sequential ad playback
- Implemented preload strategy (app start, ad transitions, pod completion)

### 4. lib/ads/analytics/ad_analytics.dart
**Reason**: Added Unity Ads and pre-roll/mid-roll analytics events
**Changes**:
- Added `logAdLoaded()` for Unity Ads load events
- Added `logAdShown()` for Unity Ads impression events
- Added `logAdCompleted()` with duration tracking
- Added `logAdSkipped()` with skip time tracking
- Added `logAdFailed()` with error code tracking
- Added `logRewardEarned()` for reward callbacks
- Added `logPreRollAdStarted()`, `logPreRollAdCompleted()`, `logPreRollAdSkipped()`, `logPreRollAdFailed()`
- Added `logAdIntervalReached()` for mid-roll timing
- Added `logStreamResumedAfterAd()` for post-ad analytics
- Added generic `logEvent()` helper method

### 5. lib/screens/player/player_overlay.dart
**Reason**: Modified pre-roll and mid-roll to use Unity Ads rewarded videos
**Changes**:
- Modified `_runPreRollThenPlay()` to call `_showPreRollAd()` instead of interstitial
- Added `_showPreRollAd()` method for Unity Ads rewarded pre-roll
- Added `_dismissAdOverlay()` to hide ad overlay
- Modified `_presentMidRollInterstitial()` to use Unity Ads ad pod
- Added ad overlay state management
- Added imports for Unity Ads service and ad logging

### 6. lib/screens/player/player_screen.dart
**Reason**: Added ad overlay state variables
**Changes**:
- Added `_showAdOverlay` boolean state
- Added `_currentAdIndex` integer state (1-based index)

### 7. lib/screens/player/player_controls_bar.dart
**Reason**: Integrated ad overlay into video surface
**Changes**:
- Modified `_buildVideoSurface()` to wrap video with `VideoPlayerAdOverlay` when `_showAdOverlay` is true
- Added `_handleAdSkip()` callback
- Added `_handleAdComplete()` callback
- Added Stack layout for video + overlay

### 8. lib/screens/player/lumio_player.dart
**Reason**: Added import for new VideoPlayerAdOverlay widget
**Changes**:
- Added import for `video_player_ad_overlay.dart`

### 9. android/app/proguard-rules.pro
**Reason**: Added Unity Ads specific ProGuard/R8 rules
**Changes**:
- Enhanced Unity Ads keep rules for better obfuscation compatibility
- Added specific rules for Unity Ads services and webview
- Added annotation and signature preservation

---

## New Files Created

### 1. lib/widgets/video_player_ad_overlay.dart
**Purpose**: Ad overlay widget for rewarded video ads in player
**Features**:
- Black opaque background (no flicker between ads)
- WillPopScope blocks back button during ad
- Skip button with 15-second countdown (disabled until countdown ends)
- Ad counter showing "Ad X of Y" in bottom-left
- 200ms fade-out animation on dismiss
- Responsive sizing for portrait and fullscreen modes
- Auto-resize on orientation change (countdown doesn't reset)

---

## Test Checklist

### Pre-roll Ad Testing
- [ ] Pre-roll shows before stream starts
- [ ] Pre-roll skip after 15s works
- [ ] Pre-roll fail → stream starts silently, no screen shown to user
- [ ] Channel change → new pre-roll triggers

### Mid-roll Ad Pod Testing
- [ ] 90s watch threshold respected
- [ ] 20-min interval triggers ad pod
- [ ] "Ad 1 of 2" → "Ad 2 of 2" counter visible
- [ ] Ad 1 → Ad 2 transition: no flicker
- [ ] Each ad has fresh 15s skip countdown
- [ ] Ad 2 fail → silent resume, user sees nothing
- [ ] All ads fail → silent resume, no overlay shown

### Player Integration Testing
- [ ] Portrait: overlay inside small player only
- [ ] Landscape: overlay fills full screen
- [ ] Rotate during ad → smooth resize, no crash
- [ ] Skip countdown doesn't reset on rotate
- [ ] Back button blocked during ad
- [ ] Pod = 1 session count (not 2)
- [ ] Session cap 4 enforced

### Anti-Bypass Testing
- [ ] App background → timer keeps counting
- [ ] App kill mid-pod → position recovered on next launch
- [ ] Network off → timer and player both pause
- [ ] Channel switch → cancel ad cycle, fresh pre-roll + 20-min timer
- [ ] Session counter persists across channel switches within same app session

### Analytics Testing
- [ ] Pre-roll events logged (started, completed, skipped, failed)
- [ ] Mid-roll events logged (pod_started, pod_completed, pod_partial)
- [ ] Unity ad events logged (loaded, shown, completed, skipped, failed)
- [ ] Ad index tracking works (1 of 2, 2 of 2)
- [ ] Stream resumed after ad event logged

---

## Complete Flow After Changes

1. **App Start** → Unity SDK init + preload Ad 1
2. **User Selects Channel** → Pre-roll Rewarded Ad (1 ad, 15s skip)
3. **Pre-roll Done/Skip** → Stream starts
4. **Pre-roll Fail** → Stream starts silently (no overlay shown)
5. **20-min Timer** → Begins after stream starts
6. **20 min + 90s watched + session < 4**:
   - Pause stream, save position
   - Show Ad Pod (Ad 1 of 2 → Ad 2 of 2)
   - No gap between ads, counter updates
   - Each ad has fresh 15s skip countdown
7. **Pod Complete** → Fade-out 200ms → Resume stream from saved position → Session counter +1 → Reset 20-min timer
8. **Rotate Mid-ad** → Overlay resizes, timer continues, ad keeps playing
9. **Ad 2 Fails** → Skip silently, resume stream, user sees nothing
10. **All Ads Fail** → Resume stream silently, user sees nothing, no screen shown
11. **Back Button During Ad** → Blocked (WillPopScope)
12. **Channel Switch** → Cancel ad cycle, fresh pre-roll + 20-min timer on new stream

---

## Configuration Requirements

### Dart Defines Required
```bash
--dart-define=UNITY_GAME_ID=800000664
--dart-define=UNITY_REWARDED_ANDROID=Rewarded_Android
--dart-define=ADS_ENABLED=true (for debug builds)
```

### Notes
- Unity Ads plugin is already in pubspec.yaml (^0.3.30)
- No changes to other ad SDKs (Adsterra, IronSource, etc.)
- Only mid-roll and pre-roll systems modified
- Banner, native, app-open, and other ad types remain unchanged
- AdMob, Monetag, channel-tap browser redirect, background ad engine not touched

---

## Analytics Events

### Pre-roll Events
- `pre_roll_ad_started`
- `pre_roll_ad_completed` (with duration)
- `pre_roll_ad_skipped` (with skip_time)
- `pre_roll_ad_failed` (with error)

### Mid-roll Events
- `ad_interval_reached`
- `unity_ad_pod_started` (with pod_size: 2)
- `unity_ad_pod_completed`
- `unity_ad_pod_partial` (with completed_count)
- `unity_ad_index` (per ad: current, total)
- `stream_resumed_after_ad` (with ads_shown, ad_type)

### Unity Ad Events
- `unity_ad_loaded` (network, format, placement)
- `unity_ad_shown` (network, format, placement)
- `unity_ad_completed` (network, format, placement, duration_seconds)
- `unity_ad_skipped` (network, format, placement, skip_time_seconds)
- `unity_ad_failed` (network, format, placement, error_code)
- `unity_ad_reward_earned` (network, placement)

---

## Summary

**Total Modified Files**: 9
**Total New Files**: 1
**Lines of Code Added**: ~300+
**Lines of Code Modified**: ~50+

All changes maintain backward compatibility with existing ad systems and only modify the pre-roll and mid-roll ad behavior as specified.