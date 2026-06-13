import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'vpn_asn_catalog.dart';

/// Confidence tier for fraud routing (see [VpnDetector.score]).
enum VpnConfidenceTier {
  clean,
  suspected,
  confirmed,
}

/// Raw signals from native + locale/TZ heuristics.
@immutable
class VpnDetectionInput {
  const VpnDetectionInput({
    required this.vpnInterfaceDetected,
    required this.vpnTransportDetected,
    required this.dnsLeakSuspicious,
    required this.vpnAppInstalled,
    required this.localeMismatch,
    required this.tzMismatch,
    this.asnMatched = false,
  });

  final bool vpnInterfaceDetected;
  final bool vpnTransportDetected;
  final bool dnsLeakSuspicious;

  /// Proxy for ASN catalog when IP→ASN lookup is unavailable on-device.
  final bool vpnAppInstalled;
  final bool localeMismatch;
  final bool tzMismatch;

  /// Set when server or future client supplies ASN ∈ [VpnAsnCatalog.top50].
  final bool asnMatched;

  int get activeLegacySignalCount =>
      (vpnInterfaceDetected ? 1 : 0) +
      (localeMismatch ? 1 : 0) +
      (tzMismatch ? 1 : 0);
}

/// Scored VPN / geo fraud result (0.0–1.0 confidence).
@immutable
class VpnDetectionResult {
  const VpnDetectionResult({
    required this.confidence,
    required this.tier,
    required this.input,
    required this.breakdown,
  });

  final double confidence;
  final VpnConfidenceTier tier;
  final VpnDetectionInput input;
  final Map<String, double> breakdown;

  bool get vpnInterfaceDetected => input.vpnInterfaceDetected;
  bool get localeMismatch => input.localeMismatch;
  bool get tzMismatch => input.tzMismatch;

  /// LevelPlay-only routing: high confidence OR legacy ≥2 boolean signals.
  bool get preferCleanSdkRouting =>
      confidence >= VpnDetector.routingThreshold ||
      input.activeLegacySignalCount >= 2;

  int get activeSignalCount => input.activeLegacySignalCount;
}

/// VPN / geo fraud scoring — Phase 2 H4.
class VpnDetector {
  VpnDetector._();

  static const MethodChannel _channel =
      MethodChannel('com.kakonzone.lumio/ads');

  /// Ad routing flips when confidence reaches this value.
  static const double routingThreshold = 0.55;

  static const double _suspectedMin = 0.35;
  static const double _confirmedMin = 0.65;

  static const double _wInterface = 0.40;
  static const double _wTransport = 0.35;
  static const double _wDnsLeak = 0.25;
  static const double _wAsnOrApp = 0.20;
  static const double _wLocale = 0.12;
  static const double _wTz = 0.12;

  /// Collect native signals (Android) and score with locale/TZ heuristics.
  static Future<VpnDetectionResult> collect({
    required bool localeMismatch,
    required bool tzMismatch,
  }) async {
    final native = await _nativeSignals();
    final input = VpnDetectionInput(
      vpnInterfaceDetected: native.vpnInterface,
      vpnTransportDetected: native.vpnTransport,
      dnsLeakSuspicious: native.dnsSuspicious,
      vpnAppInstalled: native.vpnAppInstalled,
      localeMismatch: localeMismatch,
      tzMismatch: tzMismatch,
      asnMatched: native.asnMatched,
    );
    return score(input);
  }

  /// Pure scoring for unit tests and tooling.
  @visibleForTesting
  static VpnDetectionResult score(VpnDetectionInput input) {
    final breakdown = <String, double>{};
    void add(String key, bool on, double weight) {
      if (on) breakdown[key] = weight;
    }

    add('vpn_interface', input.vpnInterfaceDetected, _wInterface);
    add('vpn_transport', input.vpnTransportDetected, _wTransport);
    add('dns_leak', input.dnsLeakSuspicious, _wDnsLeak);
    add(
      'asn_or_vpn_app',
      input.asnMatched || input.vpnAppInstalled,
      _wAsnOrApp,
    );
    add('locale_mismatch', input.localeMismatch, _wLocale);
    add('tz_mismatch', input.tzMismatch, _wTz);

    var confidence = breakdown.values.fold<double>(0, (a, b) => a + b);
    if (confidence > 1.0) confidence = 1.0;

    final tier = _tierFor(confidence);
    return VpnDetectionResult(
      confidence: confidence,
      tier: tier,
      input: input,
      breakdown: breakdown,
    );
  }

  static VpnConfidenceTier _tierFor(double confidence) {
    if (confidence >= _confirmedMin) return VpnConfidenceTier.confirmed;
    if (confidence >= _suspectedMin) return VpnConfidenceTier.suspected;
    return VpnConfidenceTier.clean;
  }

  static Future<_NativeVpnSignals> _nativeSignals() async {
    if (!Platform.isAndroid) {
      return const _NativeVpnSignals();
    }
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'collectVpnSignals',
      );
      if (raw == null) return const _NativeVpnSignals();
      return _NativeVpnSignals(
        vpnInterface: raw['vpnInterface'] == true,
        vpnTransport: raw['vpnTransport'] == true,
        dnsSuspicious: raw['dnsSuspicious'] == true,
        vpnAppInstalled: raw['vpnAppInstalled'] == true,
        asnMatched: raw['asnMatched'] == true,
      );
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[VpnDetector] native collect failed: ${e.code}');
      }
      return const _NativeVpnSignals();
    } on MissingPluginException {
      return const _NativeVpnSignals();
    }
  }
}

@immutable
class _NativeVpnSignals {
  const _NativeVpnSignals({
    this.vpnInterface = false,
    this.vpnTransport = false,
    this.dnsSuspicious = false,
    this.vpnAppInstalled = false,
    this.asnMatched = false,
  });

  final bool vpnInterface;
  final bool vpnTransport;
  final bool dnsSuspicious;
  final bool vpnAppInstalled;
  final bool asnMatched;
}
