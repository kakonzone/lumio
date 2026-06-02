import 'package:flutter/foundation.dart';

import '../core/ads/monetag_config.dart';

/// Monetag (PropellerAds-family) zone IDs — **CI dart-define only** (no defaults in release).
class MonetagConfig {
  MonetagConfig._();

  static const String _missing = '__MISSING__';

  static const String onclickZoneId = String.fromEnvironment('MONETAG_ONCLICK_ZONE');
  static const String vignetteZoneId = String.fromEnvironment('MONETAG_VIGNETTE_ZONE');
  static const String pushZoneId = String.fromEnvironment('MONETAG_PUSH_ZONE');
  static const String inPagePushZoneId = String.fromEnvironment('MONETAG_INPAGE_ZONE');
  static const String directLinkZoneId = String.fromEnvironment('MONETAG_DIRECT_ZONE');

  /// rc1 aliases (preferred in CI) with legacy fallbacks.
  static String get effectiveOnclickZoneId => MonetagZoneConfig.resolve(
        MonetagZoneConfig.zoneNative,
        onclickZoneId,
      );
  static String get effectiveVignetteZoneId => MonetagZoneConfig.resolve(
        MonetagZoneConfig.zoneInterstitial,
        vignetteZoneId,
      );
  static String get effectivePushZoneId => MonetagZoneConfig.resolve(
        MonetagZoneConfig.zoneBanner,
        pushZoneId,
      );
  static String get effectiveInPagePushZoneId => MonetagZoneConfig.resolve(
        MonetagZoneConfig.zoneBanner,
        inPagePushZoneId,
      );
  static String get effectiveDirectLinkZoneId => MonetagZoneConfig.resolve(
        MonetagZoneConfig.zoneRewarded,
        directLinkZoneId,
      );

  static const String onclickScriptHost = String.fromEnvironment('MONETAG_ONCLICK_HOST');
  static const String vignetteScriptHost = String.fromEnvironment('MONETAG_VIGNETTE_HOST');
  static const String pushScriptUrl = String.fromEnvironment('MONETAG_PUSH_SCRIPT');
  static const String inPagePushHost = String.fromEnvironment('MONETAG_INPAGE_HOST');
  static const String directLinkUrl = String.fromEnvironment('MONETAG_DIRECT_LINK');

  static bool _isSet(String v) =>
      v.trim().isNotEmpty && v.trim() != _missing;

  static bool get isConfigured =>
      _isSet(effectiveOnclickZoneId) &&
      _isSet(effectiveVignetteZoneId) &&
      _isSet(effectivePushZoneId) &&
      _isSet(effectiveInPagePushZoneId) &&
      _isSet(effectiveDirectLinkZoneId) &&
      _isSet(directLinkUrl);

  /// True when any Monetag define was provided (partial CI must not ship).
  static bool get anyDefineProvided => [
        onclickZoneId,
        vignetteZoneId,
        pushZoneId,
        inPagePushZoneId,
        directLinkZoneId,
        directLinkUrl,
        onclickScriptHost,
        vignetteScriptHost,
        pushScriptUrl,
        inPagePushHost,
      ].any(_isSet);

  /// Release: if any Monetag key is set, all must be set (no hardcoded fallbacks).
  static void assertReleaseConfiguration() {
    if (!kReleaseMode || !anyDefineProvided) return;
    final required = <String, String>{
      'MONETAG_ONCLICK_ZONE': onclickZoneId,
      'MONETAG_VIGNETTE_ZONE': vignetteZoneId,
      'MONETAG_PUSH_ZONE': pushZoneId,
      'MONETAG_INPAGE_ZONE': inPagePushZoneId,
      'MONETAG_DIRECT_ZONE': directLinkZoneId,
      'MONETAG_DIRECT_LINK': directLinkUrl,
      'MONETAG_ONCLICK_HOST': onclickScriptHost,
      'MONETAG_VIGNETTE_HOST': vignetteScriptHost,
      'MONETAG_PUSH_SCRIPT': pushScriptUrl,
      'MONETAG_INPAGE_HOST': inPagePushHost,
    };
    final missing = required.entries
        .where((e) => !_isSet(e.value))
        .map((e) => e.key)
        .toList();
    if (missing.isNotEmpty) {
      throw StateError(
        'Release requires Monetag dart-defines: ${missing.join(', ')}. '
        'See NEW_DART_DEFINES.env',
      );
    }
  }
}
