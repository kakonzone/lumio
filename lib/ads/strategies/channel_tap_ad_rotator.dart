import '../../config/app_constants.dart';
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
  /// LevelPlay interstitial — rotation slot A (mediated; not a separate SDK).
  levelPlayMediatedA,
  /// LevelPlay interstitial — rotation slot B (mediated; not a separate SDK).
  levelPlayMediatedB,
}

extension ChannelTapAdNetworkX on ChannelTapAdNetwork {
  /// Firebase / debug label — never use `unity` (misleading).
  String get analyticsName => switch (this) {
        ChannelTapAdNetwork.adsterra => 'adsterra',
        ChannelTapAdNetwork.levelPlayMediatedA => 'levelplay_interstitial_a',
        ChannelTapAdNetwork.levelPlayMediatedB => 'levelplay_interstitial_b',
      };

  /// Passed to [AdAnalytics.logInterstitialShown] via LevelPlay trigger string.
  String get interstitialTrigger => switch (this) {
        ChannelTapAdNetwork.adsterra => 'channel_tap_adsterra',
        ChannelTapAdNetwork.levelPlayMediatedA => 'channel_tap_levelplay_a',
        ChannelTapAdNetwork.levelPlayMediatedB => 'channel_tap_levelplay_b',
      };

  bool get usesLevelPlayInterstitial => this != ChannelTapAdNetwork.adsterra;
}

/// Session-wide rotation for per-channel first tap.
class ChannelTapAdRotator {
  ChannelTapAdRotator._();

  static const _allNetworks = ChannelTapAdNetwork.values;

  static List<ChannelTapAdNetwork> get _networks {
    if (AdSafetyService.instance.preferCleanSdkRouting) {
      return const [
        ChannelTapAdNetwork.levelPlayMediatedA,
        ChannelTapAdNetwork.levelPlayMediatedB,
      ];
    }
    return _allNetworks;
  }

  static Future<ChannelTapAdNetwork> next() async {
    await UserPreferences.ensureInit();
    final pool = _networks;
    final i = UserPreferences.p.getInt(AppConstants.prefChannelTapAdRotation) ?? 0;
    final network = pool[i % pool.length];
    await UserPreferences.p.setInt(
      AppConstants.prefChannelTapAdRotation,
      i + 1,
    );
    return network;
  }
}
