import 'package:flutter/foundation.dart';

import '../config/ad_config.dart' show AdConfig, AdListScreen;
import '../config/ad_policy_config.dart';
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

  /// NEWS list: native every 5 (every 4 when aggressive).
  static int get newsNativeInterval => aggressiveMode
      ? AdConfig.nativeListIntervalAggressive
      : (AdConfig.nativeDensityByScreen[AdListScreen.news] ??
          AdConfig.nativeListIntervalNews);

  /// Channel / category / favorites lists: 8 or 4.
  static int get channelListNativeInterval => aggressiveMode
      ? AdConfig.nativeListIntervalAggressive
      : AdConfig.nativeListInterval;

  static Duration get playerMidRollPeriod {
    final policy = AdPolicyConfig.instance;
    final minutes = aggressiveMode
        ? AdConfig.playerMidRollIntervalAggressiveMinutes
        : policy.midrollIntervalMinutes;
    return Duration(minutes: minutes);
  }

  /// Sticky social bar on all main tabs (Week 2 — always when configured).
  static bool get showGlobalSocialBarOverlay => AdConfig.globalSocialBarEnabled;

  /// Monetag in-page push + Adsterra social during player playback (Week 2).
  static bool get showPlayerStickySocialBar =>
      AdConfig.playerStickyMonetagEnabled;

  /// Pause overlay native after 2+ minutes of playback.
  static const Duration playerPauseAdMinPlayback = Duration(minutes: 2);
}
