/// Firebase Remote Config keys for ads, interstitial policy, and push monetization.
class RemoteConfigKeys {
  RemoteConfigKeys._();

  // Kill switches
  static const String adsEnabled = 'ads_enabled';
  static const String unityEnabled = 'unity_enabled';
  static const String adsterraEnabled = 'adsterra_enabled';
  static const String popunderSessionCap = 'popunder_session_cap';
  static const String aggressiveMode = 'aggressive_mode';
  static const String vpnLocaleStrictness = 'vpn_locale_strictness';

  // Interstitial policy (Feature A)
  static const String interstitialMaxPerSession =
      'interstitial_max_per_session';
  static const String interstitialMinGapSeconds =
      'interstitial_min_gap_seconds';
  static const String interstitialSessionCooldownSeconds =
      'interstitial_session_cooldown_seconds';
  static const String midrollIntervalMinutes = 'midroll_interval_minutes';
  static const String midrollMaxPerSession = 'midroll_max_per_session';
  static const String prerollEnabled = 'preroll_enabled';
  static const String aggressiveModeMultiplier = 'aggressive_mode_multiplier';

  // Push monetization (Feature B)
  static const String pushMonetizationEnabled = 'push_monetization_enabled';
  static const String monetagPushZoneId = 'monetag_push_zone_id';
  static const String pushPromptOnSessionNumber =
      'push_prompt_on_session_number';
  static const String pushRetryAfterDays = 'push_retry_after_days';

  static bool get aggressiveModeDefault => defaults[aggressiveMode] as bool;

  static const Map<String, Object> defaults = {
    adsEnabled: true,
    unityEnabled: true,
    adsterraEnabled: true,
    popunderSessionCap: 1,
    aggressiveMode: false,
    vpnLocaleStrictness: 'loose',
    interstitialMaxPerSession: 6,
    interstitialMinGapSeconds: 120,
    interstitialSessionCooldownSeconds: 120,
    midrollIntervalMinutes: 30,
    midrollMaxPerSession: 4,
    prerollEnabled: true,
    aggressiveModeMultiplier: 1.0,
    pushMonetizationEnabled: true,
    monetagPushZoneId: '',
    pushPromptOnSessionNumber: 2,
    pushRetryAfterDays: 3,
  };
}
