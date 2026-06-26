import 'dart:math';

import '../../config/app_constants.dart';
import '../../services/ad_safety_service.dart';
import '../../services/user_preferences.dart';

// ── Unity Ads SDK integration ─────────────────────────────────────────────────────
// Unity Ads runs as a direct SDK (no mediation layer).
// Rotation slots [unityA] and [unityB] are two Unity Ads interstitial
// presentations with different analytics triggers.

/// First channel-tap presentation slots (Adsterra browser vs Unity Ads interstitial).
enum ChannelTapAdNetwork {
  adsterra,

  /// Unity Ads interstitial — rotation slot A.
  unityA,

  /// Unity Ads interstitial — rotation slot B.
  unityB,
}

extension ChannelTapAdNetworkX on ChannelTapAdNetwork {
  /// Firebase / debug label.
  String get analyticsName => switch (this) {
        ChannelTapAdNetwork.adsterra => 'adsterra',
        ChannelTapAdNetwork.unityA => 'unity_interstitial_a',
        ChannelTapAdNetwork.unityB => 'unity_interstitial_b',
      };

  /// Passed to [AdAnalytics.logInterstitialShown] via Unity Ads trigger string.
  String get interstitialTrigger => switch (this) {
        ChannelTapAdNetwork.adsterra => 'channel_tap_adsterra',
        ChannelTapAdNetwork.unityA => 'channel_tap_unity_a',
        ChannelTapAdNetwork.unityB => 'channel_tap_unity_b',
      };

  bool get usesUnityInterstitial =>
      this == ChannelTapAdNetwork.unityA || this == ChannelTapAdNetwork.unityB;
}

/// Session-wide rotation for per-channel first tap.
class ChannelTapAdRotator {
  ChannelTapAdRotator._();

  static final _rng = Random();

  /// Sequential rotation: Adsterra → Unity A → Unity B → loop (Monetag removed)
  static ChannelTapAdNetwork selectFirstTapNetwork() {
    if (AdSafetyService.instance.preferCleanSdkRouting) {
      return _rng.nextBool()
          ? ChannelTapAdNetwork.unityA
          : ChannelTapAdNetwork.unityB;
    }
    final roll = _rng.nextInt(100);
    if (roll < 70) return ChannelTapAdNetwork.adsterra;
    return roll < 85
        ? ChannelTapAdNetwork.unityA
        : ChannelTapAdNetwork.unityB;
  }

  /// Sequential rotation: tap 1→Adsterra, tap 2→Unity A, tap 3→Unity B, loop (Monetag removed)
  static Future<ChannelTapAdNetwork> next() async {
    await UserPreferences.ensureInit();
    final i =
        UserPreferences.p.getInt(AppConstants.prefChannelTapAdRotation) ?? 0;
    final rotationIndex = i % 3;

    final network = switch (rotationIndex) {
      0 => ChannelTapAdNetwork.adsterra, // Adsterra direct
      1 => ChannelTapAdNetwork.unityA, // Unity A
      2 => ChannelTapAdNetwork.unityB, // Unity B
      _ => ChannelTapAdNetwork.adsterra,
    };

    await UserPreferences.p.setInt(
      AppConstants.prefChannelTapAdRotation,
      i + 1,
    );
    return network;
  }
}
