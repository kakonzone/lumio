import 'package:flutter/foundation.dart';

import '../config/ad_config.dart';
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
      : AdConfig.nativeListIntervalNews;

  /// Channel / category / favorites lists: 8 or 4.
  static int get channelListNativeInterval => aggressiveMode
      ? AdConfig.nativeListIntervalAggressive
      : AdConfig.nativeListInterval;

  static Duration get playerMidRollPeriod => Duration(
        minutes: aggressiveMode
            ? AdConfig.playerMidRollIntervalAggressiveMinutes
            : AdConfig.playerMidRollIntervalMinutes,
      );

  /// Sticky social bar on all main tabs (HOME overlay stack).
  static bool get showGlobalSocialBarOverlay => aggressiveMode;
}
