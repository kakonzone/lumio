import 'package:flutter/foundation.dart';

import '../config/ad_config.dart' show AdConfig, AdListScreen;
import '../config/ad_policy_config.dart';
import '../services/app_config_service.dart';
import 'ad_log.dart';
import '../services/ad_safety_service.dart';

/// Screen-level placement rules — see `docs/PLACEMENT_MAP.md`.
class AdPlacementConfig {
  AdPlacementConfig._();

  /// Unit tests only — overrides [AdSafetyService.aggressiveMode].
  @visibleForTesting
  static bool? debugAggressiveModeOverride;

  static bool get aggressiveMode =>
      debugAggressiveModeOverride ?? AdSafetyService.instance.aggressiveMode;

  /// Log once per process for device checklist (grep `[Placement]`).
  static void logPlacementSummaryOnce() {
    if (_loggedSummary) return;
    _loggedSummary = true;
    adLog(
      '[Placement] aggressive_mode=$aggressiveMode '
      'news_native_every=$newsNativeInterval '
      'channel_native_every=$channelListNativeInterval '
      'player_midroll_min=${playerMidRollPeriod.inMinutes} '
      'social_bar=$showGlobalSocialBarOverlay',
    );
  }

  static bool _loggedSummary = false;

  @visibleForTesting
  static void debugResetSummaryLog() {
    _loggedSummary = false;
    debugAggressiveModeOverride = null;
  }

  static int get channelListNativeInterval => listNativeInterval;

  /// In-feed native ad every N channel rows (Appwrite `list_native_interval`, default 8).
  static int get listNativeInterval {
    if (debugAggressiveModeOverride == true || aggressiveMode) {
      return AdConfig.nativeListIntervalAggressive;
    }
    final remote =
        AppConfigService.instance.cachedConfig.listNativeInterval;
    if (remote > 0) return remote;
    return AdConfig.nativeListInterval;
  }

  /// NEWS list uses the same interval as channel lists.
  static int get newsNativeInterval => listNativeInterval;

  static Duration get playerMidRollPeriod {
    final policy = AdPolicyConfig.instance;
    final minutes = aggressiveMode
        ? AdConfig.playerMidRollIntervalAggressiveMinutes
        : policy.midrollIntervalMinutes;
    return Duration(minutes: minutes);
  }

  /// Sticky social bar on all main tabs (Week 2 — always when configured).
  static bool get showGlobalSocialBarOverlay =>
      AdConfig.globalSocialBarEnabled &&
      AdSafetyService.instance.bannerEnabledRemote;

  /// Monetag in-page push + Adsterra social during player playback (Week 2).
  static bool get showPlayerStickySocialBar =>
      AdConfig.playerStickyMonetagEnabled;

  /// Pause overlay native after 2+ minutes of playback.
  static const Duration playerPauseAdMinPlayback = Duration(minutes: 2);
}
