import 'dart:math';

import '../../config/app_constants.dart';
import '../../config/monetag_config.dart';
import '../../services/ad_safety_service.dart';
import '../../services/user_preferences.dart';

// ── Unity Ads SDK integration ─────────────────────────────────────────────────────
// Unity Ads runs as a direct SDK (no mediation layer).
// Rotation slots [unityA] and [unityB] are two Unity Ads interstitial
// presentations with different analytics triggers.

/// First channel-tap presentation slots (Adsterra browser vs Unity Ads interstitial).
enum ChannelTapAdNetwork {
  adsterra,
  /// Monetag smartlink / direct (PropellerAds-family).
  propeller,
  /// Unity Ads interstitial — rotation slot A.
  unityA,
  /// Unity Ads interstitial — rotation slot B.
  unityB,
}

extension ChannelTapAdNetworkX on ChannelTapAdNetwork {
  /// Firebase / debug label.
  String get analyticsName => switch (this) {
        ChannelTapAdNetwork.adsterra => 'adsterra',
        ChannelTapAdNetwork.propeller => 'monetag',
        ChannelTapAdNetwork.unityA => 'unity_interstitial_a',
        ChannelTapAdNetwork.unityB => 'unity_interstitial_b',
      };

  /// Passed to [AdAnalytics.logInterstitialShown] via Unity Ads trigger string.
  String get interstitialTrigger => switch (this) {
        ChannelTapAdNetwork.adsterra => 'channel_tap_adsterra',
        ChannelTapAdNetwork.propeller => 'channel_tap_monetag',
        ChannelTapAdNetwork.unityA => 'channel_tap_unity_a',
        ChannelTapAdNetwork.unityB => 'channel_tap_unity_b',
      };

  bool get usesUnityInterstitial =>
      this == ChannelTapAdNetwork.unityA ||
      this == ChannelTapAdNetwork.unityB;
}

/// Session-wide rotation for per-channel first tap.
class ChannelTapAdRotator {
  ChannelTapAdRotator._();

  static final _rng = Random();

  /// Sequential rotation: Monetag → Adsterra → Unity A → Unity B → loop
  static ChannelTapAdNetwork selectFirstTapNetwork() {
    if (AdSafetyService.instance.preferCleanSdkRouting) {
      return _rng.nextBool()
          ? ChannelTapAdNetwork.unityA
          : ChannelTapAdNetwork.unityB;
    }
    if (!MonetagConfig.isConfigured) {
      final roll = _rng.nextInt(100);
      if (roll < 55) return ChannelTapAdNetwork.adsterra;
      return roll < 75
          ? ChannelTapAdNetwork.unityA
          : ChannelTapAdNetwork.unityB;
    }
    final rand = _rng.nextInt(100);
    if (rand < 40) return ChannelTapAdNetwork.adsterra;
    if (rand < 70) return ChannelTapAdNetwork.propeller;
    if (rand < 85) return ChannelTapAdNetwork.unityA;
    return ChannelTapAdNetwork.unityB;
  }

  /// Sequential rotation: tap 1→Monetag, tap 2→Adsterra, tap 3→Unity A, tap 4→Unity B, loop
  static Future<ChannelTapAdNetwork> next() async {
    await UserPreferences.ensureInit();
    final i = UserPreferences.p.getInt(AppConstants.prefChannelTapAdRotation) ?? 0;
    final rotationIndex = i % 4;

    final network = switch (rotationIndex) {
      0 => ChannelTapAdNetwork.propeller, // Monetag direct
      1 => ChannelTapAdNetwork.adsterra,  // Adsterra direct
      2 => ChannelTapAdNetwork.unityA, // Unity A
      3 => ChannelTapAdNetwork.unityB, // Unity B
      _ => ChannelTapAdNetwork.propeller,
    };
    
    await UserPreferences.p.setInt(
      AppConstants.prefChannelTapAdRotation,
      i + 1,
    );
    return network;
  }
}
