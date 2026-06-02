import 'package:flutter/foundation.dart';

/// Monetag zone IDs — **CI `--dart-define` only** (empty default = ads disabled).
class MonetagZoneConfig {
  MonetagZoneConfig._();

  static const String zoneInterstitial = String.fromEnvironment(
    'MONETAG_ZONE_INTERSTITIAL',
    defaultValue: '',
  );
  static const String zoneRewarded = String.fromEnvironment(
    'MONETAG_ZONE_REWARDED',
    defaultValue: '',
  );
  static const String zoneBanner = String.fromEnvironment(
    'MONETAG_ZONE_BANNER',
    defaultValue: '',
  );
  static const String zoneNative = String.fromEnvironment(
    'MONETAG_ZONE_NATIVE',
    defaultValue: '',
  );

  static bool _isSet(String v) => v.trim().isNotEmpty;

  static String resolve(String rc1Zone, String legacyZone) {
    if (_isSet(rc1Zone)) return rc1Zone.trim();
    if (_isSet(legacyZone)) return legacyZone.trim();
    return '';
  }

  static void logMissing(String placement) {
    if (kDebugMode) {
      debugPrint(
        '[Monetag] skip $placement — zone ID empty (set MONETAG_ZONE_* dart-define)',
      );
    }
  }
}
