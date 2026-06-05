import 'dart:ui' as ui;

/// Tier-1 markets require a licensed CMP before ad SDK init (UK/US/EU-style).
class CmpTier1Gate {
  CmpTier1Gate._();

  /// Flip to true when a licensed CMP SDK is integrated (IAB TCF).
  static const bool cmpLicensedEnabled = bool.fromEnvironment(
    'CMP_LICENSED_ENABLED',
    defaultValue: false,
  );

  static const Set<String> _tier1CountryCodes = {
    'uk',
    'gb',
    'us',
    'ca',
    'au',
    'de',
    'fr',
  };

  /// BD / IN / PK and other markets are not gated here.
  static String? deviceCountryCode() {
    final code = ui.PlatformDispatcher.instance.locale.countryCode;
    if (code == null || code.isEmpty) return null;
    return code.toLowerCase();
  }

  static bool get isTier1Market {
    final cc = deviceCountryCode();
    if (cc == null) return false;
    return _tier1CountryCodes.contains(cc);
  }

  static const Set<String> _primaryMarkets = {'bd', 'in', 'pk'};

  static bool _isTier1Code(String? code) {
    if (code == null || code.isEmpty) return false;
    return _tier1CountryCodes.contains(code.toLowerCase());
  }

  /// When true, do not initialize ad SDKs (no UA traffic without CMP).
  ///
  /// Uses SIM/network country when available so en_GB locale on a BD SIM
  /// does not block ads.
  static bool blocksAdSdkInitFor({
    String? localeCountry,
    String? simCountry,
    String? networkCountry,
  }) {
    if (cmpLicensedEnabled) return false;

    final sim = simCountry?.toLowerCase();
    final net = networkCountry?.toLowerCase();
    if (_primaryMarkets.contains(sim) || _primaryMarkets.contains(net)) {
      return false;
    }

    if (_isTier1Code(sim) || _isTier1Code(net)) return true;
    return !cmpLicensedEnabled && isTier1Market;
  }

  @Deprecated('Use blocksAdSdkInitFor after AdSafetyService.ensureReady')
  static bool get blocksAdSdkInit =>
      blocksAdSdkInitFor(localeCountry: deviceCountryCode());
}
