/// Remote app configuration from Appwrite `app_config` / `global_config`.
class AppConfigModel {
  const AppConfigModel({
    required this.key,
    this.jsonPayload,
    this.updatedAt,
    this.adsEnabled = true,
    this.levelplayEnabled = true,
    this.adsterraEnabled = true,
    this.monetagEnabled = true,
    this.aggressiveMode = false,
    this.bannerEnabled = true,
    this.popunderEnabled = true,
    this.interstitialCooldown = 90,
    this.channelTapsBeforeAd = 3,
    this.spinWheelEnabled = true,
    this.newsEnabled = true,
    this.specialLinkEnabled = true,
    this.defaultQuality = '540p',
    this.bufferingTimeout = 12,
    this.maxFailover = 3,
    this.showAnnouncement = false,
    this.announcementText,
    this.showTicker = false,
    this.tickerText,
    this.latestVersion = '1.0.0',
    this.minimumVersion = '1.0.0',
    this.forceUpdate = false,
    this.updateUrl,
    this.updateMessage,
    this.killSwitch = false,
    this.killMessage,
    this.maintenanceMode = false,
    this.maintenanceMessage,
  });

  final String key;
  final String? jsonPayload;
  final String? updatedAt;
  final bool adsEnabled;
  final bool levelplayEnabled;
  final bool adsterraEnabled;
  final bool monetagEnabled;
  final bool aggressiveMode;
  final bool bannerEnabled;
  final bool popunderEnabled;
  final int interstitialCooldown;
  final int channelTapsBeforeAd;
  final bool spinWheelEnabled;
  final bool newsEnabled;
  final bool specialLinkEnabled;
  final String defaultQuality;
  final int bufferingTimeout;
  final int maxFailover;
  final bool showAnnouncement;
  final String? announcementText;
  final bool showTicker;
  final String? tickerText;
  final String latestVersion;
  final String minimumVersion;
  final bool forceUpdate;
  final String? updateUrl;
  final String? updateMessage;
  final bool killSwitch;
  final String? killMessage;
  final bool maintenanceMode;
  final String? maintenanceMessage;

  factory AppConfigModel.fromMap(Map<String, dynamic> map) {
    return AppConfigModel(
      key: _str(map, 'key', 'key', defaultValue: 'global_config'),
      jsonPayload: _nullableStr(map, 'json_payload', 'jsonPayload'),
      updatedAt: _nullableStr(map, 'updated_at', 'updatedAt'),
      adsEnabled: _bool(map, 'ads_enabled', 'adsEnabled', defaultValue: true),
      levelplayEnabled:
          _bool(map, 'levelplay_enabled', 'levelplayEnabled', defaultValue: true),
      adsterraEnabled:
          _bool(map, 'adsterra_enabled', 'adsterraEnabled', defaultValue: true),
      monetagEnabled:
          _bool(map, 'monetag_enabled', 'monetagEnabled', defaultValue: true),
      aggressiveMode:
          _bool(map, 'aggressive_mode', 'aggressiveMode', defaultValue: false),
      bannerEnabled:
          _bool(map, 'banner_enabled', 'bannerEnabled', defaultValue: true),
      popunderEnabled:
          _bool(map, 'popunder_enabled', 'popunderEnabled', defaultValue: true),
      interstitialCooldown:
          _int(map, 'interstitial_cooldown', 'interstitialCooldown', defaultValue: 90),
      channelTapsBeforeAd: _int(
        map,
        'channel_taps_before_ad',
        'channelTapsBeforeAd',
        defaultValue: 3,
      ),
      spinWheelEnabled:
          _bool(map, 'spin_wheel_enabled', 'spinWheelEnabled', defaultValue: true),
      newsEnabled: _bool(map, 'news_enabled', 'newsEnabled', defaultValue: true),
      specialLinkEnabled: _bool(
        map,
        'special_link_enabled',
        'specialLinkEnabled',
        defaultValue: true,
      ),
      defaultQuality:
          _str(map, 'default_quality', 'defaultQuality', defaultValue: '540p'),
      bufferingTimeout:
          _int(map, 'buffering_timeout', 'bufferingTimeout', defaultValue: 12),
      maxFailover: _int(map, 'max_failover', 'maxFailover', defaultValue: 3),
      showAnnouncement: _bool(
        map,
        'show_announcement',
        'showAnnouncement',
        defaultValue: false,
      ),
      announcementText:
          _nullableStr(map, 'announcement_text', 'announcementText'),
      showTicker: _bool(map, 'show_ticker', 'showTicker', defaultValue: false),
      tickerText: _nullableStr(map, 'ticker_text', 'tickerText'),
      latestVersion:
          _str(map, 'latest_version', 'latestVersion', defaultValue: '1.0.0'),
      minimumVersion:
          _str(map, 'minimum_version', 'minimumVersion', defaultValue: '1.0.0'),
      forceUpdate: _bool(map, 'force_update', 'forceUpdate', defaultValue: false),
      updateUrl: _nullableStr(map, 'update_url', 'updateUrl'),
      updateMessage: _nullableStr(map, 'update_message', 'updateMessage'),
      killSwitch: _bool(map, 'kill_switch', 'killSwitch', defaultValue: false),
      killMessage: _nullableStr(map, 'kill_message', 'killMessage'),
      maintenanceMode:
          _bool(map, 'maintenance_mode', 'maintenanceMode', defaultValue: false),
      maintenanceMessage:
          _nullableStr(map, 'maintenance_message', 'maintenanceMessage'),
    );
  }

  factory AppConfigModel.defaultConfig() =>
      const AppConfigModel(key: 'global_config');

  AppConfigModel copyWith({
    String? key,
    String? jsonPayload,
    String? updatedAt,
    bool? adsEnabled,
    bool? levelplayEnabled,
    bool? adsterraEnabled,
    bool? monetagEnabled,
    bool? aggressiveMode,
    bool? bannerEnabled,
    bool? popunderEnabled,
    int? interstitialCooldown,
    int? channelTapsBeforeAd,
    bool? spinWheelEnabled,
    bool? newsEnabled,
    bool? specialLinkEnabled,
    String? defaultQuality,
    int? bufferingTimeout,
    int? maxFailover,
    bool? showAnnouncement,
    String? announcementText,
    bool? showTicker,
    String? tickerText,
    String? latestVersion,
    String? minimumVersion,
    bool? forceUpdate,
    String? updateUrl,
    String? updateMessage,
    bool? killSwitch,
    String? killMessage,
    bool? maintenanceMode,
    String? maintenanceMessage,
  }) {
    return AppConfigModel(
      key: key ?? this.key,
      jsonPayload: jsonPayload ?? this.jsonPayload,
      updatedAt: updatedAt ?? this.updatedAt,
      adsEnabled: adsEnabled ?? this.adsEnabled,
      levelplayEnabled: levelplayEnabled ?? this.levelplayEnabled,
      adsterraEnabled: adsterraEnabled ?? this.adsterraEnabled,
      monetagEnabled: monetagEnabled ?? this.monetagEnabled,
      aggressiveMode: aggressiveMode ?? this.aggressiveMode,
      bannerEnabled: bannerEnabled ?? this.bannerEnabled,
      popunderEnabled: popunderEnabled ?? this.popunderEnabled,
      interstitialCooldown: interstitialCooldown ?? this.interstitialCooldown,
      channelTapsBeforeAd: channelTapsBeforeAd ?? this.channelTapsBeforeAd,
      spinWheelEnabled: spinWheelEnabled ?? this.spinWheelEnabled,
      newsEnabled: newsEnabled ?? this.newsEnabled,
      specialLinkEnabled: specialLinkEnabled ?? this.specialLinkEnabled,
      defaultQuality: defaultQuality ?? this.defaultQuality,
      bufferingTimeout: bufferingTimeout ?? this.bufferingTimeout,
      maxFailover: maxFailover ?? this.maxFailover,
      showAnnouncement: showAnnouncement ?? this.showAnnouncement,
      announcementText: announcementText ?? this.announcementText,
      showTicker: showTicker ?? this.showTicker,
      tickerText: tickerText ?? this.tickerText,
      latestVersion: latestVersion ?? this.latestVersion,
      minimumVersion: minimumVersion ?? this.minimumVersion,
      forceUpdate: forceUpdate ?? this.forceUpdate,
      updateUrl: updateUrl ?? this.updateUrl,
      updateMessage: updateMessage ?? this.updateMessage,
      killSwitch: killSwitch ?? this.killSwitch,
      killMessage: killMessage ?? this.killMessage,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'json_payload': jsonPayload,
        'updated_at': updatedAt,
        'ads_enabled': adsEnabled,
        'levelplay_enabled': levelplayEnabled,
        'adsterra_enabled': adsterraEnabled,
        'monetag_enabled': monetagEnabled,
        'aggressive_mode': aggressiveMode,
        'banner_enabled': bannerEnabled,
        'popunder_enabled': popunderEnabled,
        'interstitial_cooldown': interstitialCooldown,
        'channel_taps_before_ad': channelTapsBeforeAd,
        'spin_wheel_enabled': spinWheelEnabled,
        'news_enabled': newsEnabled,
        'special_link_enabled': specialLinkEnabled,
        'default_quality': defaultQuality,
        'buffering_timeout': bufferingTimeout,
        'max_failover': maxFailover,
        'show_announcement': showAnnouncement,
        'announcement_text': announcementText,
        'show_ticker': showTicker,
        'ticker_text': tickerText,
        'latest_version': latestVersion,
        'minimum_version': minimumVersion,
        'force_update': forceUpdate,
        'update_url': updateUrl,
        'update_message': updateMessage,
        'kill_switch': killSwitch,
        'kill_message': killMessage,
        'maintenance_mode': maintenanceMode,
        'maintenance_message': maintenanceMessage,
      };

  static String _str(
    Map<String, dynamic> map,
    String snake,
    String camel, {
    required String defaultValue,
  }) {
    final raw = map[snake] ?? map[camel];
    if (raw == null) return defaultValue;
    final text = raw.toString().trim();
    return text.isEmpty ? defaultValue : text;
  }

  static String? _nullableStr(
    Map<String, dynamic> map,
    String snake,
    String camel,
  ) {
    final raw = map[snake] ?? map[camel];
    if (raw == null) return null;
    final text = raw.toString().trim();
    return text.isEmpty ? null : text;
  }

  static bool _bool(
    Map<String, dynamic> map,
    String snake,
    String camel, {
    required bool defaultValue,
  }) {
    final raw = map[snake] ?? map[camel];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final v = raw.trim().toLowerCase();
      if (v == 'true' || v == '1' || v == 'yes') return true;
      if (v == 'false' || v == '0' || v == 'no') return false;
    }
    return defaultValue;
  }

  static int _int(
    Map<String, dynamic> map,
    String snake,
    String camel, {
    required int defaultValue,
  }) {
    final raw = map[snake] ?? map[camel];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? defaultValue;
    return defaultValue;
  }
}
