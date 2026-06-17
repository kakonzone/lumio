import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/ad_config.dart';
import '../config/remote_config_keys.dart';
import 'firebase_bootstrap.dart';
import 'secure_install_id_store.dart';
import 'vpn_signal_service.dart';

/// Routing hint from combined VPN / geo signals.
enum AdRoutingPreference {
  standard,

  /// ≥2 fraud signals — prefer Unity Ads over Adsterra.
  preferCleanSdk,
}

/// Device identity, VPN signals, Remote Config kill switches.
class AdSafetyService {
  AdSafetyService._();
  static final AdSafetyService instance = AdSafetyService._();

  static const _prefFingerprint = 'lumio_device_fingerprint';
  static const _prefInstallId = 'lumio_install_id';

  String? _fingerprint;
  String? _installId;
  String? _simCountry;
  String? _networkCountry;

  VpnSignals _vpnSignals = const VpnSignals(
    vpnInterfaceDetected: false,
    localeMismatch: false,
    tzMismatch: false,
    confidence: 0,
    tier: VpnConfidenceTier.clean,
  );
  bool _remoteReady = false;
  FirebaseRemoteConfig? _remote;
  bool _identityLogged = false;

  /// Non-release builds block ads unless `--dart-define=ADS_ENABLED=true`.
  ///
  /// Release APK always allows ad init (ignores debug dart-defines).
  bool get adsBlockedInDebug =>
      _debugAdsBlockedInDebug ?? AdConfig.blockAdsInThisBuild;

  @visibleForTesting
  void debugSetAdsBlockedInDebug(bool? value) =>
      _debugAdsBlockedInDebug = value;

  String get deviceFingerprint => _fingerprint ?? 'unknown';

  String get installId => _installId ?? 'unknown';

  VpnSignals get vpnSignals => _vpnSignals;

  String? get simCountry => _simCountry;

  String? get networkCountry => _networkCountry;

  /// Legacy name — true when ≥2 VPN/geo signals active.
  bool get vpnHeuristicTier1 => _vpnSignals.preferCleanSdkRouting;

  AdRoutingPreference get adRoutingPreference =>
      _vpnSignals.preferCleanSdkRouting
          ? AdRoutingPreference.preferCleanSdk
          : AdRoutingPreference.standard;

  bool get preferCleanSdkRouting =>
      _debugPreferCleanSdkRouting ?? _vpnSignals.preferCleanSdkRouting;

  @visibleForTesting
  void debugSetPreferCleanSdkRouting(bool? value) =>
      _debugPreferCleanSdkRouting = value;

  Future<void> ensureReady() async {
    _logAdBuildGating();
    await _loadOrCreateInstallId();
    await _loadOrCreateFingerprint();
    await _evaluateVpnSignals();
    // INTENTIONALLY OMITTED: Play Integrity disabled, server must rely on HMAC + install-ID dedup
    if (!_remoteReady) {
      await prefetchRemoteConfig();
    }
    logIdentityDiagnostics();
  }

  /// Call from `main()` after [FirebaseBootstrap.initialize] (before ads).
  Future<void> prefetchRemoteConfig() async {
    if (!FirebaseBootstrap.isInitialized) return;
    await _initRemoteConfig();
  }

  Future<void> _loadOrCreateInstallId() async {
    final prefs = await SharedPreferences.getInstance();
    final secure = SecureInstallIdStore.instance;

    final fromSecure = await secure.read();
    if (fromSecure != null && fromSecure.length >= 32) {
      _installId = fromSecure;
      if (prefs.getString(_prefInstallId) != fromSecure) {
        await prefs.setString(_prefInstallId, fromSecure);
      }
      return;
    }

    final fromPrefs = prefs.getString(_prefInstallId);
    if (fromPrefs != null && fromPrefs.length >= 32) {
      _installId = fromPrefs;
      await secure.write(fromPrefs);
      return;
    }

    final legacyFingerprint = prefs.getString(_prefFingerprint);
    if (legacyFingerprint != null && legacyFingerprint.length >= 16) {
      _installId = deriveInstallIdFromLegacyFingerprint(legacyFingerprint);
      await _persistInstallId(_installId!);
      if (!kReleaseMode) {
        debugPrint('[AdSafety] migrated installId from legacy fingerprint');
      }
      return;
    }

    _installId = _generateInstallId();
    await _persistInstallId(_installId!);
  }

  /// Stable upgrade path when only [ _prefFingerprint ] existed.
  @visibleForTesting
  static String deriveInstallIdFromLegacyFingerprint(String legacy) {
    final raw = '$legacy|${AdConfig.fingerprintMigrationSalt}';
    final hash = sha256.convert(utf8.encode(raw)).toString();
    return '${hash.substring(0, 8)}-${hash.substring(8, 12)}-'
        '${hash.substring(12, 16)}-${hash.substring(16, 20)}-'
        '${hash.substring(20, 32)}';
  }

  Future<void> _persistInstallId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefInstallId, id);
    await SecureInstallIdStore.instance.write(id);
  }

  static String _generateInstallId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-'
        '${h.substring(20, 32)}';
  }

  Future<void> _loadOrCreateFingerprint() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_prefFingerprint);
    if (cached != null && cached.length >= 48) {
      _fingerprint = cached;
      return;
    }

    final deviceSignals = await _deviceSignals();
    final raw = '${_installId!}|$deviceSignals';
    final hash = sha256.convert(utf8.encode(raw)).toString();
    _fingerprint = hash;
    await prefs.setString(_prefFingerprint, _fingerprint!);
  }

  Future<String> _deviceSignals() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final android = await deviceInfo.androidInfo;
      return [
        android.model,
        android.manufacturer,
        android.brand,
        android.fingerprint,
      ].join('|');
    } catch (e) {
      if (!kReleaseMode) debugPrint('[AdSafety] device signals: $e');
      return 'unknown_device';
    }
  }

  void logIdentityDiagnostics() {
    if (_identityLogged) return;
    _identityLogged = true;
    if (kReleaseMode) return;
    debugPrint(
      '[AdSafety] installId=$installId fingerprint=$deviceFingerprint '
      'vpn_confidence=${_vpnSignals.confidence.toStringAsFixed(2)} '
      'vpn_tier=${_vpnSignals.tier.name} '
      'vpn_signals interfaces=${_vpnSignals.vpnInterfaceDetected} '
      'transport=${_vpnSignals.vpnTransportDetected} '
      'dns_leak=${_vpnSignals.dnsLeakSuspicious} '
      'vpn_app=${_vpnSignals.vpnAppInstalled} '
      'locale_mismatch=${_vpnSignals.localeMismatch} '
      'tz_mismatch=${_vpnSignals.tzMismatch} '
      'routing=${adRoutingPreference.name} '
      'aggressive_mode=$aggressiveMode',
    );
  }

  void _logAdBuildGating() {
    if (kReleaseMode) return;
    if (AdConfig.adsEnabledDefine) {
      debugPrint(
          '[AdSafety] ADS_ENABLED=true — ads enabled in non-release build');
      return;
    }
    if (AdConfig.adsTestModeEffective) {
      debugPrint('[AdSafety] ADS_TEST_MODE=true — ads enabled (legacy)');
      return;
    }
    debugPrint(
      '[AdSafety] ads blocked in non-release build — '
      'pass --dart-define=ADS_ENABLED=true (see docs/AD_TESTING.md)',
    );
  }

  Future<void> _evaluateVpnSignals() async {
    final telephony = await VpnSignalService.readTelephonyCountries();
    _simCountry = telephony.$1;
    _networkCountry = telephony.$2;
    _vpnSignals = await VpnSignalService.instance.collect();
  }

  Future<void> _initRemoteConfig() async {
    try {
      _remote = FirebaseRemoteConfig.instance;
      await _remote!.setDefaults(RemoteConfigKeys.defaults);
      await _remote!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval:
              kReleaseMode ? const Duration(hours: 12) : Duration.zero,
        ),
      );
      final activated = await _remote!.fetchAndActivate();
      _remoteReady = true;
      final rc = _remote!;
      debugPrint('[RemoteConfig] keys=${rc.getAll().keys.toList()}');
      debugPrint(
        '[RemoteConfig] values: ads_enabled=${rc.getBool(RemoteConfigKeys.adsEnabled)}, '
        'unity_enabled=${rc.getBool(RemoteConfigKeys.unityEnabled)}, '
        'adsterra_enabled=${rc.getBool(RemoteConfigKeys.adsterraEnabled)}, '
        'vpn_locale_strictness=${rc.getString(RemoteConfigKeys.vpnLocaleStrictness)}',
      );
      // ignore: avoid_print
      print(
        '[RemoteConfig] fetchAndActivate activated=$activated '
        'ads=${rc.getBool(RemoteConfigKeys.adsEnabled)} '
        'unity=${rc.getBool(RemoteConfigKeys.unityEnabled)} '
        'adsterra=${rc.getBool(RemoteConfigKeys.adsterraEnabled)}',
      );
    } catch (e) {
      if (!kReleaseMode) debugPrint('[AdSafety] Remote Config skipped: $e');
      _remoteReady = false;
    }
  }

  bool get remoteConfigReady => _remoteReady;

  bool _rcBool(String key) {
    if (!_remoteReady || _remote == null) {
      return RemoteConfigKeys.defaults[key] as bool;
    }
    return _remote!.getBool(key);
  }

  /// Master kill switch — when false, [AdManager.adsEnabled] is false.
  bool get adsEnabledRemote => AdConfig.remoteAdsEnabled;

  /// Unity Ads SDK layer kill switch.
  bool get unityEnabledRemote => AdConfig.unityEnabled;

  bool? _debugAdsterraEnabled;
  int? _debugPopunderSessionCap;
  bool? _debugAdsBlockedInDebug;
  bool? _debugPreferCleanSdkRouting;
  bool? _debugAggressiveMode;

  @visibleForTesting
  void debugSetAggressiveMode(bool? value) => _debugAggressiveMode = value;

  bool get adsterraEnabled {
    if (_debugAdsterraEnabled != null) return _debugAdsterraEnabled!;
    if (adsBlockedInDebug) return false;
    if (preferCleanSdkRouting) return false;
    return _adsterraEnabledFromRemote;
  }

  /// Post-splash app-open promo — VPN routing does not block Adsterra here.
  bool get adsterraEnabledForColdStart {
    if (_debugAdsterraEnabled != null) return _debugAdsterraEnabled!;
    if (adsBlockedInDebug) return false;
    return _adsterraEnabledFromRemote;
  }

  bool get _adsterraEnabledFromRemote => AdConfig.adsterraEnabled;

  @visibleForTesting
  void debugSetAdsterraEnabled(bool? enabled) =>
      _debugAdsterraEnabled = enabled;

  int get popunderSessionCap {
    if (_debugPopunderSessionCap != null) return _debugPopunderSessionCap!;
    if (!_remoteReady || _remote == null) {
      return RemoteConfigKeys.defaults[RemoteConfigKeys.popunderSessionCap]
          as int;
    }
    return _remote!.getInt(RemoteConfigKeys.popunderSessionCap);
  }

  @visibleForTesting
  void debugSetPopunderSessionCap(int? cap) => _debugPopunderSessionCap = cap;

  /// Appwrite `aggressive_mode` — denser natives, social bar overlay, shorter mid-roll.
  bool get aggressiveMode {
    if (_debugAggressiveMode != null) return _debugAggressiveMode!;
    return AdConfig.aggressiveMode;
  }

  /// Monetag layer kill switch (Appwrite global_config).
  bool get monetagEnabledRemote => AdConfig.monetagEnabled;

  /// Banner placements kill switch.
  bool get bannerEnabledRemote => AdConfig.bannerEnabled;

  /// Popunder placements kill switch.
  bool get popunderEnabledRemote => AdConfig.popunderEnabled;

  /// `off` | `loose` | `strict` — see [VpnSignalService.evaluateLocaleFraud].
  String get vpnLocaleStrictness {
    if (!_remoteReady || _remote == null) {
      return RemoteConfigKeys.defaults[RemoteConfigKeys.vpnLocaleStrictness]
          as String;
    }
    final v = _remote!.getString(RemoteConfigKeys.vpnLocaleStrictness).trim();
    if (v == 'off' || v == 'strict') return v;
    return 'loose';
  }
}
