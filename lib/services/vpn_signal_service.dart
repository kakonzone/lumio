import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ad_safety_service.dart';
import 'fraud/vpn_detector.dart';

export 'fraud/vpn_detector.dart' show VpnConfidenceTier;

/// VPN / geo mismatch signals for ad routing (confidence 0.0–1.0).
class VpnSignals {
  const VpnSignals({
    required this.vpnInterfaceDetected,
    required this.localeMismatch,
    required this.tzMismatch,
    required this.confidence,
    required this.tier,
    this.vpnTransportDetected = false,
    this.dnsLeakSuspicious = false,
    this.vpnAppInstalled = false,
  });

  final bool vpnInterfaceDetected;
  final bool localeMismatch;
  final bool tzMismatch;
  final double confidence;
  final VpnConfidenceTier tier;
  final bool vpnTransportDetected;
  final bool dnsLeakSuspicious;
  final bool vpnAppInstalled;

  factory VpnSignals.fromResult(VpnDetectionResult result) {
    return VpnSignals(
      vpnInterfaceDetected: result.vpnInterfaceDetected,
      localeMismatch: result.localeMismatch,
      tzMismatch: result.tzMismatch,
      confidence: result.confidence,
      tier: result.tier,
      vpnTransportDetected: result.input.vpnTransportDetected,
      dnsLeakSuspicious: result.input.dnsLeakSuspicious,
      vpnAppInstalled: result.input.vpnAppInstalled,
    );
  }

  int get activeSignalCount =>
      (vpnInterfaceDetected ? 1 : 0) +
      (localeMismatch ? 1 : 0) +
      (tzMismatch ? 1 : 0);

  bool get preferCleanSdkRouting =>
      confidence >= VpnDetector.routingThreshold || activeSignalCount >= 2;
}

class VpnSignalService {
  VpnSignalService._();
  static final VpnSignalService instance = VpnSignalService._();

  static const MethodChannel _vpnChannel =
      MethodChannel('com.kakonzone.lumio/ads');

  Future<VpnSignals> collect() async {
    final locale = PlatformDispatcher.instance.locale;
    final native = await _readAndroidTelephonyCountries();
    final strictness = AdSafetyService.instance.vpnLocaleStrictness;

    final localeMismatch = VpnSignalService.evaluateLocaleFraud(
      simCountry: native.$1,
      telephonyCountry: native.$2,
      ipGeoCountry: null,
      localeCountry: locale.countryCode,
      localeLanguage: locale.languageCode,
      strictness: strictness,
    );

    final tz = southAsiaTimezoneMismatch(DateTime.now().timeZoneOffset);
    final result = await VpnDetector.collect(
      localeMismatch: localeMismatch,
      tzMismatch: tz,
    );
    return VpnSignals.fromResult(result);
  }

  static Future<(String?, String?)> readTelephonyCountries() =>
      _readAndroidTelephonyCountries();

  static Future<(String?, String?)> _readAndroidTelephonyCountries() async {
    if (!Platform.isAndroid) return (null, null);
    try {
      final raw = await _vpnChannel.invokeMethod<Map<Object?, Object?>>(
        'collectVpnSignals',
      );
      if (raw == null) return (null, null);
      String? pick(Object? v) {
        final s = v as String?;
        if (s == null || s.trim().isEmpty) return null;
        return s.trim().toUpperCase();
      }

      return (pick(raw['simCountry']), pick(raw['networkCountry']));
    } on PlatformException {
      return (null, null);
    }
  }

  /// Legitimate South Asian markets with English UI (not VPN fraud).
  @visibleForTesting
  static bool isAllowedMarketLocale(String? country, String? language) {
    final c = country?.toUpperCase() ?? '';
    final lang = language?.toLowerCase() ?? '';
    if (lang != 'en') return false;
    return c == 'BD' || c == 'IN' || c == 'PK';
  }

  /// Two-of-three disagreement among SIM, telephony, IP-geo (when known).
  ///
  /// Unknown SIM → never flag. [strictness]: `off` | `loose` | `strict` (RC).
  @visibleForTesting
  static bool evaluateLocaleFraud({
    required String? simCountry,
    required String? telephonyCountry,
    required String? ipGeoCountry,
    required String? localeCountry,
    required String? localeLanguage,
    required String strictness,
  }) {
    if (strictness == 'off') return false;
    if (isAllowedMarketLocale(localeCountry, localeLanguage)) return false;

    final sim = simCountry?.toUpperCase();
    if (sim == null || sim.isEmpty) return false;

    final tel = (telephonyCountry ?? '').toUpperCase();
    final ip = ipGeoCountry?.toUpperCase();
    final loc = localeCountry?.toUpperCase() ?? '';

    final known = <String>[sim];
    if (tel.isNotEmpty) known.add(tel);
    if (ip != null && ip.isNotEmpty) known.add(ip);
    if (loc.isNotEmpty) known.add(loc);

    if (strictness == 'strict') {
      return known.toSet().length >= 3;
    }

    // loose: at least two pairwise mismatches among sim / telephony / ip
    if (ip != null && ip.isNotEmpty && tel.isNotEmpty) {
      var mismatches = 0;
      if (sim != tel) mismatches++;
      if (sim != ip) mismatches++;
      if (tel != ip) mismatches++;
      if (mismatches >= 2) return true;
    }

    // Without IP-geo: flag only when SIM differs from locale country (non-allowlisted)
    if (loc.isNotEmpty && sim != loc) return true;

    return false;
  }

  /// Device clock is South Asia (+5–7h) — independent of locale fraud.
  @visibleForTesting
  static bool southAsiaTimezoneMismatch(Duration offset) {
    final offsetHours = offset.inHours;
    return offsetHours >= 5 && offsetHours <= 7;
  }
}
