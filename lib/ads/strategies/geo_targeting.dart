import 'dart:ui' as ui;

/// BD/IN/PK vs USA/UK interstitial multiplier.
class GeoTargeting {
  GeoTargeting._();

  static const _premiumRegions = {'us', 'gb', 'uk', 'ca', 'au'};

  static const _highFrequencyRegions = {
    'bd',
    'in',
    'pk',
    'np',
    'lk',
  };

  static String currentCountryCode() {
    try {
      return ui.PlatformDispatcher.instance.locale.countryCode?.toLowerCase() ??
          '';
    } catch (_) {
      return '';
    }
  }

  static bool get isPremiumRegion =>
      _premiumRegions.contains(currentCountryCode());

  static bool get isHighFrequencyRegion =>
      _highFrequencyRegions.contains(currentCountryCode());

  /// Premium: fewer interstitials. High-frequency: default. Others: slightly more.
  static double interstitialMultiplier() {
    if (isPremiumRegion) return 0.6;
    if (isHighFrequencyRegion) return 1.0;
    return 0.85;
  }

  static int adjustedMaxInterstitials(int baseMax) {
    final m = interstitialMultiplier();
    return (baseMax * m).round().clamp(2, baseMax);
  }
}
