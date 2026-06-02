import 'dart:math';

import '../../config/app_constants.dart';
import '../../config/monetag_config.dart';
import '../../services/ad_safety_service.dart';
import '../../services/user_preferences.dart';

// ── Unity Ads is NOT a separate SDK in this app ─────────────────────────────
// Unity Ads runs only as a mediated network inside the LevelPlay dashboard.
// There is no UnityAds.initialize() / show() call. Rotation slots
// [levelPlayMediatedA] and [levelPlayMediatedB] are two LevelPlay interstitial
// presentations with different analytics triggers — same LevelPlayInterstitialAd
// unit (Unity Ads may win inside mediation; no Unity SDK in this app).

/// First channel-tap presentation slots (Adsterra browser vs LevelPlay interstitial).
enum ChannelTapAdNetwork {
  adsterra,
  /// Monetag smartlink / direct (PropellerAds-family).
  propeller,
  /// LevelPlay interstitial — rotation slot A (mediated; not a separate SDK).
  levelPlayMediatedA,
  /// LevelPlay interstitial — rotation slot B (mediated; Unity may win in mediation).
  levelPlayMediatedB,
}

extension ChannelTapAdNetworkX on ChannelTapAdNetwork {
  /// Firebase / debug label — never use `unity` (misleading).
  String get analyticsName => switch (this) {
        ChannelTapAdNetwork.adsterra => 'adsterra',
        ChannelTapAdNetwork.propeller => 'monetag',
        ChannelTapAdNetwork.levelPlayMediatedA => 'levelplay_interstitial_a',
        ChannelTapAdNetwork.levelPlayMediatedB => 'levelplay_interstitial_b',
      };

  /// Passed to [AdAnalytics.logInterstitialShown] via LevelPlay trigger string.
  String get interstitialTrigger => switch (this) {
        ChannelTapAdNetwork.adsterra => 'channel_tap_adsterra',
        ChannelTapAdNetwork.propeller => 'channel_tap_monetag',
        ChannelTapAdNetwork.levelPlayMediatedA => 'channel_tap_levelplay_a',
        ChannelTapAdNetwork.levelPlayMediatedB => 'channel_tap_levelplay_b',
      };

  bool get usesLevelPlayInterstitial =>
      this == ChannelTapAdNetwork.levelPlayMediatedA ||
      this == ChannelTapAdNetwork.levelPlayMediatedB;
}

/// Session-wide rotation for per-channel first tap.
class ChannelTapAdRotator {
  ChannelTapAdRotator._();

  static final _rng = Random();

  /// Week 2 weighted first-tap allocation (40/30/15/15).
  static ChannelTapAdNetwork selectFirstTapNetwork() {
    if (AdSafetyService.instance.preferCleanSdkRouting) {
      return _rng.nextBool()
          ? ChannelTapAdNetwork.levelPlayMediatedA
          : ChannelTapAdNetwork.levelPlayMediatedB;
    }
    if (!MonetagConfig.isConfigured) {
      final roll = _rng.nextInt(100);
      if (roll < 55) return ChannelTapAdNetwork.adsterra;
      return roll < 75
          ? ChannelTapAdNetwork.levelPlayMediatedA
          : ChannelTapAdNetwork.levelPlayMediatedB;
    }
    final rand = _rng.nextInt(100);
    if (rand < 40) return ChannelTapAdNetwork.adsterra;
    if (rand < 70) return ChannelTapAdNetwork.propeller;
    if (rand < 85) return ChannelTapAdNetwork.levelPlayMediatedA;
    return ChannelTapAdNetwork.levelPlayMediatedB;
  }

  /// Legacy round-robin — delegates to weighted picker.
  static Future<ChannelTapAdNetwork> next() async {
    await UserPreferences.ensureInit();
    final network = selectFirstTapNetwork();
    final i = UserPreferences.p.getInt(AppConstants.prefChannelTapAdRotation) ?? 0;
    await UserPreferences.p.setInt(
      AppConstants.prefChannelTapAdRotation,
      i + 1,
    );
    return network;
  }
}
