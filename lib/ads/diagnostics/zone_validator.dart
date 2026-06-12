import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../config/ad_config.dart';
import '../../config/monetag_config.dart';
import '../../services/ad_safety_service.dart';
import '../../utils/ad_debug_log.dart';

class ZoneValidationResult {
  const ZoneValidationResult({
    required this.network,
    required this.zoneId,
    required this.placement,
    required this.result,
    required this.latencyMs,
    this.formatDetected = 'unknown',
    this.detail = '',
  });

  final String network;
  final String zoneId;
  final String placement;
  final String result;
  final int latencyMs;
  final String formatDetected;
  final String detail;
}

/// Diagnostics-only zone probe (no user-visible ad render).
class ZoneValidator {
  ZoneValidator._();
  static final ZoneValidator instance = ZoneValidator._();

  Future<List<ZoneValidationResult>> validateAll() async {
    if (!AdConfig.diagnosticsEnabled) {
      return const [];
    }
    await AdSafetyService.instance.ensureReady();
    final results = <ZoneValidationResult>[];
    for (final zone in _inventory()) {
      final sw = Stopwatch()..start();
      final ok = zone.probeUrl.trim().isNotEmpty;
      sw.stop();
      final result = ok ? 'configured' : 'missing_config';
      final row = ZoneValidationResult(
        network: zone.network,
        zoneId: zone.zoneId,
        placement: zone.placement,
        result: result,
        latencyMs: sw.elapsedMilliseconds,
        formatDetected: zone.format,
        detail: zone.probeUrl,
      );
      results.add(row);
      _emitTelemetry(row);
    }
    return results;
  }

  void _emitTelemetry(ZoneValidationResult row) {
    final payload = {
      'network': row.network,
      'zone_id': row.zoneId,
      'placement': row.placement,
      'result': row.result,
      'latency_ms': row.latencyMs,
      'format_detected': row.formatDetected,
    };
    debugPrint('[Lumio] lumio_zone_validation $payload');
    AdDebugLog.info(
      'ZoneValidator',
      'lumio_zone_validation ${row.network} zone=${row.zoneId} '
      'placement=${row.placement} result=${row.result} '
      'latency_ms=${row.latencyMs} format=${row.formatDetected}',
    );
  }

  List<_ZoneProbe> _inventory() {
    return [
      // LevelPlay zone probes removed during deprecation
      // ISSUE: Add Unity Ads zone validation when available
      // See: https://github.com/your-repo/issues/XXX
      // _ZoneProbe(
      //   network: 'unity',
      //   zoneId: _mask(AdConfig.interstitialAdUnitId),
      //   placement: 'interstitial',
      //   format: 'interstitial',
      //   probeUrl: AdConfig.interstitialAdUnitId,
      // ),
      // _ZoneProbe(
      //   network: 'unity',
      //   zoneId: _mask(AdConfig.bannerAdUnitId),
      //   placement: 'banner',
      //   format: 'banner',
      //   probeUrl: AdConfig.bannerAdUnitId,
      // ),
      _ZoneProbe(
        network: 'adsterra',
        zoneId: 'direct_link',
        placement: 'channel_tap',
        format: 'direct',
        probeUrl: AdConfig.adsterraDirectLinksReleaseSafe.isNotEmpty
            ? AdConfig.adsterraDirectLinksReleaseSafe.first
            : '',
      ),
      _ZoneProbe(
        network: 'adsterra',
        zoneId: 'popunder',
        placement: 'webview',
        format: 'popunder',
        probeUrl: AdConfig.adsterraPopunderScriptUrl,
      ),
      _ZoneProbe(
        network: 'adsterra',
        zoneId: 'native',
        placement: 'webview',
        format: 'native',
        probeUrl: AdConfig.adsterraNativeInvokeUrl,
      ),
      _ZoneProbe(
        network: 'adsterra',
        zoneId: 'banner728',
        placement: 'webview',
        format: 'banner',
        probeUrl: AdConfig.adsterraBanner728InvokeUrl,
      ),
      _ZoneProbe(
        network: 'monetag',
        zoneId: _mask(MonetagConfig.onclickZoneId),
        placement: 'onclick',
        format: 'onclick',
        probeUrl: MonetagConfig.onclickScriptHost,
      ),
      _ZoneProbe(
        network: 'monetag',
        zoneId: _mask(MonetagConfig.vignetteZoneId),
        placement: 'vignette',
        format: 'vignette',
        probeUrl: MonetagConfig.vignetteScriptHost,
      ),
      _ZoneProbe(
        network: 'monetag',
        zoneId: _mask(MonetagConfig.inPagePushZoneId),
        placement: 'inpage_push',
        format: 'inpage_push',
        probeUrl: MonetagConfig.inPagePushHost,
      ),
      _ZoneProbe(
        network: 'monetag',
        zoneId: _mask(MonetagConfig.directLinkZoneId),
        placement: 'direct',
        format: 'direct',
        probeUrl: MonetagConfig.directLinkUrl,
      ),
    ];
  }

  static String _mask(String id) {
    final t = id.trim();
    if (t.length <= 4) return t;
    return '${t.substring(0, 2)}***${t.substring(t.length - 2)}';
  }
}

class _ZoneProbe {
  const _ZoneProbe({
    required this.network,
    required this.zoneId,
    required this.placement,
    required this.format,
    required this.probeUrl,
  });

  final String network;
  final String zoneId;
  final String placement;
  final String format;
  final String probeUrl;
}
