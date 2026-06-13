import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Kill switch service for emergency app/ad control.
/// Fetches config from GitHub and caches locally.
class KillSwitchService {
  KillSwitchService._();

  static final KillSwitchService _instance = KillSwitchService._();
  static KillSwitchService get instance => _instance;

  static const String _owner =
      String.fromEnvironment('KILL_SWITCH_OWNER', defaultValue: '');
  static const String _cacheKey = 'kill_switch_cache';
  static const String _cacheTimestampKey = 'kill_switch_cache_timestamp';
  static const Duration _cacheValidity = Duration(minutes: 15);

  KillSwitchConfig? _config;
  bool _initialized = false;

  /// Fetch and parse kill switch config from GitHub.
  /// Returns true on success or fail-open (network error).
  Future<bool> initialize() async {
    if (_owner.isEmpty) {
      debugPrint(
          '[KillSwitch] KILL_SWITCH_OWNER not set - skipping kill switch check');
      _config = KillSwitchConfig.fallback();
      _initialized = true;
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final cachedTimestamp = prefs.getInt(_cacheTimestampKey);
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check cache validity
    if (cachedTimestamp != null &&
        (now - cachedTimestamp) < _cacheValidity.inMilliseconds) {
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null) {
        try {
          _config = KillSwitchConfig.fromJson(jsonDecode(cachedJson));
          _initialized = true;
          debugPrint('[KillSwitch] Using cached config');
          return true;
        } catch (e) {
          debugPrint('[KillSwitch] Cache parse error: $e');
        }
      }
    }

    // Fetch fresh config
    try {
      final url = Uri.parse(
          'https://raw.githubusercontent.com/$_owner/lumio-config/main/status.json');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _config = KillSwitchConfig.fromJson(json);

        // Cache the response
        await prefs.setString(_cacheKey, response.body);
        await prefs.setInt(_cacheTimestampKey, now);

        _initialized = true;
        debugPrint('[KillSwitch] Fetched fresh config from GitHub');
        return true;
      } else {
        debugPrint('[KillSwitch] HTTP ${response.statusCode} - using fallback');
        _config = KillSwitchConfig.fallback();
        _initialized = true;
        return true; // Fail-open
      }
    } catch (e) {
      debugPrint('[KillSwitch] Fetch error: $e - using fallback');
      _config = KillSwitchConfig.fallback();
      _initialized = true;
      return true; // Fail-open on network error
    }
  }

  KillSwitchConfig get config {
    if (!_initialized) {
      debugPrint('[KillSwitch] Not initialized, returning fallback');
      return KillSwitchConfig.fallback();
    }
    return _config ?? KillSwitchConfig.fallback();
  }

  bool get appEnabled => config.appEnabled;
  bool get adsEnabled => config.adsEnabled;
  bool get levelplayEnabled => config.levelplayEnabled;
  bool get adsterraEnabled => config.adsterraEnabled;
  bool get monetagEnabled => config.monetagEnabled;
  String? get forceUpdateVersion => config.forceUpdateVersion;
  String? get maintenanceMessageBn => config.maintenanceMessageBn;
}

class KillSwitchConfig {
  const KillSwitchConfig({
    required this.appEnabled,
    required this.adsEnabled,
    required this.levelplayEnabled,
    required this.adsterraEnabled,
    required this.monetagEnabled,
    this.forceUpdateVersion,
    this.maintenanceMessageBn,
  });

  final bool appEnabled;
  final bool adsEnabled;
  final bool levelplayEnabled;
  final bool adsterraEnabled;
  final bool monetagEnabled;
  final String? forceUpdateVersion;
  final String? maintenanceMessageBn;

  factory KillSwitchConfig.fromJson(Map<String, dynamic> json) {
    return KillSwitchConfig(
      appEnabled: json['app_enabled'] as bool? ?? true,
      adsEnabled: json['ads_enabled'] as bool? ?? true,
      levelplayEnabled: json['levelplay_enabled'] as bool? ?? true,
      adsterraEnabled: json['adsterra_enabled'] as bool? ?? true,
      monetagEnabled: json['monetag_enabled'] as bool? ?? true,
      forceUpdateVersion: json['force_update_version'] as String?,
      maintenanceMessageBn: json['maintenance_message_bn'] as String?,
    );
  }

  factory KillSwitchConfig.fallback() {
    return const KillSwitchConfig(
      appEnabled: true,
      adsEnabled: true,
      levelplayEnabled: true,
      adsterraEnabled: true,
      monetagEnabled: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'app_enabled': appEnabled,
      'ads_enabled': adsEnabled,
      'levelplay_enabled': levelplayEnabled,
      'adsterra_enabled': adsterraEnabled,
      'monetag_enabled': monetagEnabled,
      if (forceUpdateVersion != null)
        'force_update_version': forceUpdateVersion,
      if (maintenanceMessageBn != null)
        'maintenance_message_bn': maintenanceMessageBn,
    };
  }
}
