import 'package:firebase_remote_config/firebase_remote_config.dart';

import 'ad_config.dart';
import '../services/ad_safety_service.dart';
import 'remote_config_keys.dart';

/// RC-overridable interstitial / mid-roll / pre-roll caps (Firebase defaults in [RemoteConfigKeys]).
class AdPolicyConfig {
  AdPolicyConfig._();
  static final AdPolicyConfig instance = AdPolicyConfig._();

  FirebaseRemoteConfig? get _rc => AdSafetyService.instance.remoteConfigReady
      ? FirebaseRemoteConfig.instance
      : null;

  double get aggressiveModeMultiplier {
    if (!AdSafetyService.instance.aggressiveMode) return 1.0;
    final fallback = RemoteConfigKeys
        .defaults[RemoteConfigKeys.aggressiveModeMultiplier]! as double;
    final raw =
        _rc?.getDouble(RemoteConfigKeys.aggressiveModeMultiplier) ?? fallback;
    return raw.clamp(0.5, 2.0);
  }

  int get interstitialMaxPerSession => _scaleMax(
        _int(
          RemoteConfigKeys.interstitialMaxPerSession,
          AdConfig.maxInterstitialsPerSession,
        ),
      );

  int get interstitialMaxPerHour => AdConfig.interstitialMaxPerHour;

  int get interstitialMinGapSeconds => _scaleCooldown(
        _int(
          RemoteConfigKeys.interstitialMinGapSeconds,
          AdConfig.interstitialMinGapSeconds,
        ),
      );

  int get interstitialSessionCooldownSeconds => _scaleCooldown(
        _int(
          RemoteConfigKeys.interstitialSessionCooldownSeconds,
          AdConfig.interstitialCooldownSeconds,
        ),
      );

  int get midrollIntervalMinutes => _int(
        RemoteConfigKeys.midrollIntervalMinutes,
        AdConfig.playerMidRollIntervalMinutes,
      );

  int get midrollMaxPerSession => _int(
        RemoteConfigKeys.midrollMaxPerSession,
        AdConfig.midRollMaxPerSession,
      );

  bool get prerollEnabled => _bool(
        RemoteConfigKeys.prerollEnabled,
        AdConfig.prerollEnabled,
      );

  bool get pushMonetizationEnabled => _bool(
        RemoteConfigKeys.pushMonetizationEnabled,
        true,
      );

  String get monetagPushZoneId {
    final fromRc =
        _rc?.getString(RemoteConfigKeys.monetagPushZoneId).trim() ?? '';
    if (fromRc.isNotEmpty) return fromRc;
    return '';
  }

  int get pushPromptOnSessionNumber => _int(
        RemoteConfigKeys.pushPromptOnSessionNumber,
        2,
      );

  int get pushRetryAfterDays => _int(
        RemoteConfigKeys.pushRetryAfterDays,
        3,
      );

  int _int(String key, int fallback) {
    final defaults = RemoteConfigKeys.defaults[key];
    if (_rc == null) return defaults is int ? defaults : fallback;
    return _rc!.getInt(key);
  }

  bool _bool(String key, bool fallback) {
    final defaults = RemoteConfigKeys.defaults[key];
    if (_rc == null) return defaults is bool ? defaults : fallback;
    return _rc!.getBool(key);
  }

  int _scaleCooldown(int base) {
    final m = aggressiveModeMultiplier;
    if (m <= 1.0) return base;
    return (base / m).round().clamp(1, base);
  }

  int _scaleMax(int base) {
    final m = aggressiveModeMultiplier;
    if (m <= 1.0) return base;
    return (base * m).round();
  }
}
