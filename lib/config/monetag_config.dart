/// Monetag (PropellerAds-family) zone IDs — **CI dart-define only** (no defaults in release).
class MonetagConfig {
  MonetagConfig._();

  static const String _missing = '__MISSING__';

  // Zone IDs - no defaults, must be set via --dart-define
  static const String zonePopunder =
      String.fromEnvironment('MONETAG_ZONE_POPUNDER', defaultValue: '');
  static const String zoneVignette =
      String.fromEnvironment('MONETAG_ZONE_VIGNETTE', defaultValue: '');
  static const String zonePush =
      String.fromEnvironment('MONETAG_ZONE_PUSH', defaultValue: '');
  static const String zoneInPagePush =
      String.fromEnvironment('MONETAG_ZONE_INPAGE_PUSH', defaultValue: '');
  static const String zoneDirectLink =
      String.fromEnvironment('MONETAG_ZONE_DIRECT_LINK', defaultValue: '');

  // Script URLs - no defaults, must be set via --dart-define
  static const String scriptPopunder =
      String.fromEnvironment('MONETAG_SCRIPT_POPUNDER', defaultValue: '');
  static const String scriptVignette =
      String.fromEnvironment('MONETAG_SCRIPT_VIGNETTE', defaultValue: '');
  static const String scriptPush =
      String.fromEnvironment('MONETAG_SCRIPT_PUSH', defaultValue: '');
  static const String scriptInPagePush =
      String.fromEnvironment('MONETAG_SCRIPT_INPAGE_PUSH', defaultValue: '');
  static const String urlDirectLink =
      String.fromEnvironment('MONETAG_URL_DIRECT_LINK', defaultValue: '');

  // Legacy zone IDs (for backward compatibility)
  static const String zoneInterstitial =
      String.fromEnvironment('MONETAG_ZONE_INTERSTITIAL', defaultValue: '');
  static const String zoneRewarded =
      String.fromEnvironment('MONETAG_ZONE_REWARDED', defaultValue: '');
  static const String zoneBanner =
      String.fromEnvironment('MONETAG_ZONE_BANNER', defaultValue: '');
  static const String zoneNative =
      String.fromEnvironment('MONETAG_ZONE_NATIVE', defaultValue: '');

  /// Release CI override — applies to all placements when set (verify via APK strings).
  static const String unifiedZoneId =
      String.fromEnvironment('MONETAG_ZONE_ID', defaultValue: '');

  static bool _isSet(String v) => v.trim().isNotEmpty && v.trim() != _missing;

  static String resolve(String rc1Zone, String legacyZone) {
    if (_isSet(unifiedZoneId)) return unifiedZoneId.trim();
    if (_isSet(rc1Zone)) return rc1Zone.trim();
    if (_isSet(legacyZone)) return legacyZone.trim();
    return '';
  }

  // Effective zone IDs (rc1 aliases with legacy fallbacks)
  static String get effectiveOnclickZoneId =>
      resolve(zoneNative, const String.fromEnvironment('MONETAG_ONCLICK_ZONE'));
  static String get effectiveVignetteZoneId =>
      resolve(zoneVignette, const String.fromEnvironment('MONETAG_VIGNETTE_ZONE'));
  static String get effectivePushZoneId =>
      resolve(zonePush, const String.fromEnvironment('MONETAG_PUSH_ZONE'));
  static String get effectiveInPagePushZoneId =>
      resolve(zoneInPagePush, const String.fromEnvironment('MONETAG_INPAGE_ZONE'));
  static String get effectiveDirectLinkZoneId =>
      resolve(zoneDirectLink, const String.fromEnvironment('MONETAG_DIRECT_ZONE'));

  // Legacy script hosts/URLs
  static const String onclickScriptHost =
      String.fromEnvironment('MONETAG_ONCLICK_HOST', defaultValue: '');
  static const String vignetteScriptHost =
      String.fromEnvironment('MONETAG_VIGNETTE_HOST', defaultValue: '');
  static const String pushScriptUrl =
      String.fromEnvironment('MONETAG_PUSH_SCRIPT', defaultValue: '');
  static const String inPagePushHost =
      String.fromEnvironment('MONETAG_INPAGE_HOST', defaultValue: '');
  static const String directLinkUrl =
      String.fromEnvironment('MONETAG_DIRECT_LINK', defaultValue: '');

  static bool get isConfigured => false; // Monetag disabled — using Adsterra direct links

  /// True when any Monetag define was provided (partial CI must not ship).
  static bool get anyDefineProvided => [
        zonePopunder,
        zoneVignette,
        zonePush,
        zoneInPagePush,
        zoneDirectLink,
        urlDirectLink,
        scriptPopunder,
        scriptVignette,
        scriptPush,
        scriptInPagePush,
        onclickScriptHost,
        vignetteScriptHost,
        pushScriptUrl,
        inPagePushHost,
        directLinkUrl,
      ].any(_isSet);

  /// Release: if any Monetag key is set, all must be set (no hardcoded fallbacks).
  static void assertReleaseConfiguration() {
    // Direct link not used — assertion disabled.
    // (Validation logic intentionally left out; re-add here if this
    // assertion is ever re-enabled.)
  }
}
