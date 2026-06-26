import 'dart:math';

import '../../config/app_constants.dart';
import '../../services/ad_safety_service.dart';
import '../../services/user_preferences.dart';

/// First channel-tap presentation slot (Adsterra browser only).
enum ChannelTapAdNetwork {
  adsterra,
}

extension ChannelTapAdNetworkX on ChannelTapAdNetwork {
  /// Firebase / debug label.
  String get analyticsName => switch (this) {
        ChannelTapAdNetwork.adsterra => 'adsterra',
      };

  /// Passed to [AdAnalytics.logInterstitialShown] via trigger string.
  String get interstitialTrigger => switch (this) {
        ChannelTapAdNetwork.adsterra => 'channel_tap_adsterra',
      };

  bool get usesUnityInterstitial => false;
}

/// Session-wide rotation for per-channel first tap.
class ChannelTapAdRotator {
  ChannelTapAdRotator._();

  static final _rng = Random();

  /// Always return Adsterra (Unity and Monetag removed)
  static ChannelTapAdNetwork selectFirstTapNetwork() {
    return ChannelTapAdNetwork.adsterra;
  }

  /// Always return Adsterra (Unity and Monetag removed)
  static Future<ChannelTapAdNetwork> next() async {
    await UserPreferences.ensureInit();
    final i =
        UserPreferences.p.getInt(AppConstants.prefChannelTapAdRotation) ?? 0;
    
    await UserPreferences.p.setInt(
      AppConstants.prefChannelTapAdRotation,
      i + 1,
    );
    return ChannelTapAdNetwork.adsterra;
  }
}
