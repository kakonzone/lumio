import 'package:flutter/foundation.dart';

/// Monetag zone IDs and script URLs — **CI `--dart-define` only** (empty default = ads disabled).
class MonetagZoneConfig {
  MonetagZoneConfig._();

  // Zone IDs
  static const String zonePopunder = String.fromEnvironment(
    'MONETAG_ZONE_POPUNDER',
    defaultValue: '11062342',
  );
  static const String zoneVignette = String.fromEnvironment(
    'MONETAG_ZONE_VIGNETTE',
    defaultValue: '11062367',
  );
  static const String zonePush = String.fromEnvironment(
    'MONETAG_ZONE_PUSH',
    defaultValue: '11062382',
  );
  static const String zoneInPagePush = String.fromEnvironment(
    'MONETAG_ZONE_INPAGE_PUSH',
    defaultValue: '11062385',
  );
  static const String zoneDirectLink = String.fromEnvironment(
    'MONETAG_ZONE_DIRECT_LINK',
    defaultValue: '11062386',
  );

  // Script URLs
  static const String scriptPopunder = String.fromEnvironment(
    'MONETAG_SCRIPT_POPUNDER',
    defaultValue: 'https://al5sm.com/tag.min.js',
  );
  static const String scriptVignette = String.fromEnvironment(
    'MONETAG_SCRIPT_VIGNETTE',
    defaultValue: 'https://n6wxm.com/vignette.min.js',
  );
  static const String scriptPush = String.fromEnvironment(
    'MONETAG_SCRIPT_PUSH',
    defaultValue: 'https://5gvci.com/act/files/tag.min.js',
  );
  static const String scriptInPagePush = String.fromEnvironment(
    'MONETAG_SCRIPT_INPAGE_PUSH',
    defaultValue: 'https://nap5k.com/tag.min.js',
  );
  static const String urlDirectLink = String.fromEnvironment(
    'MONETAG_URL_DIRECT_LINK',
    defaultValue: 'https://omg10.com/4/11062386',
  );

  // Legacy zone IDs (for backward compatibility)
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

  /// Release CI override — applies to all placements when set (verify via APK strings).
  static const String unifiedZoneId = String.fromEnvironment(
    'MONETAG_ZONE_ID',
    defaultValue: '',
  );

  static bool _isSet(String v) => v.trim().isNotEmpty;

  static String resolve(String rc1Zone, String legacyZone) {
    if (_isSet(unifiedZoneId)) return unifiedZoneId.trim();
    if (_isSet(rc1Zone)) return rc1Zone.trim();
    if (_isSet(legacyZone)) return legacyZone.trim();
    return '';
  }

  static bool get isConfigured =>
      _isSet(zonePopunder) ||
      _isSet(zoneVignette) ||
      _isSet(zonePush) ||
      _isSet(zoneInPagePush) ||
      _isSet(zoneDirectLink) ||
      _isSet(zoneInterstitial) ||
      _isSet(zoneRewarded) ||
      _isSet(zoneBanner) ||
      _isSet(zoneNative);

  static void logMissing(String placement) {
    if (kDebugMode) {
      debugPrint(
        '[Monetag] skip $placement — zone ID empty (set MONETAG_ZONE_* dart-define)',
      );
    }
  }

  /// Get popunder script HTML
  static String getPopunderScript() {
    return '''
<script>(function(s){s.dataset.zone='$zonePopunder',s.src='$scriptPopunder'})([document.documentElement, document.body].filter(Boolean).pop().appendChild(document.createElement('script')))</script>
    ''';
  }

  /// Get vignette script HTML
  static String getVignetteScript() {
    return '''
<script>(function(s){s.dataset.zone='$zoneVignette',s.src='$scriptVignette'})([document.documentElement, document.body].filter(Boolean).pop().appendChild(document.createElement('script')))</script>
    ''';
  }

  /// Get push notification script HTML
  static String getPushScript() {
    return '''
<script src="$scriptPush" data-cfasync="false" async></script>
    ''';
  }

  /// Get in-page push script HTML
  static String getInPagePushScript() {
    return '''
<script>(function(s){s.dataset.zone='$zoneInPagePush',s.src='$scriptInPagePush'})([document.documentElement, document.body].filter(Boolean).pop().appendChild(document.createElement('script')))</script>
    ''';
  }

  /// Get direct link URL
  static String getDirectLinkUrl() {
    return urlDirectLink;
  }
}
