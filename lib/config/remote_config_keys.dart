/// Firebase Remote Config keys for ad kill switches.
class RemoteConfigKeys {
  RemoteConfigKeys._();

  static const String adsEnabled = 'ads_enabled';
  static const String levelPlayEnabled = 'levelplay_enabled';
  static const String adsterraEnabled = 'adsterra_enabled';
  static const String popunderSessionCap = 'popunder_session_cap';
  static const String aggressiveMode = 'aggressive_mode';
  static const String vpnLocaleStrictness = 'vpn_locale_strictness';

  /// Default for [aggressiveMode] — denser placements when RC true.
  static bool get aggressiveModeDefault =>
      defaults[aggressiveMode] as bool;

  static const Map<String, Object> defaults = {
    adsEnabled: true,
    levelPlayEnabled: true,
    adsterraEnabled: true,
    popunderSessionCap: 2,
    aggressiveMode: false,
    vpnLocaleStrictness: 'loose',
  };
}
