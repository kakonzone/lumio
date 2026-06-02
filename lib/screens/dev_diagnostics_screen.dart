import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../ads/ad_cold_start_eligibility.dart';
import '../ads/ad_manager.dart';
import '../ads/adsterra/adsterra_native_cache.dart';
import '../ads/diagnostics/zone_validator.dart';
import '../config/ad_config.dart';
import '../services/ad_health_monitor.dart';
import '../services/ad_safety_service.dart';
import '../services/server_cap.dart';
import '../services/ironsource_service.dart';
import '../theme/app_theme.dart';

/// Ad stack diagnostics — compile with `--dart-define=DIAGNOSTICS_ENABLED=true`.
class DevDiagnosticsScreen extends StatefulWidget {
  const DevDiagnosticsScreen({super.key});

  @override
  State<DevDiagnosticsScreen> createState() => _DevDiagnosticsScreenState();
}

class _DevDiagnosticsScreenState extends State<DevDiagnosticsScreen> {
  Timer? _refreshTimer;
  PackageInfo? _packageInfo;
  List<ZoneValidationResult> _zoneResults = [];
  bool _zoneValidating = false;
  AdColdStartEligibilityReport? _coldStartReport;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPackageInfo());
    unawaited(_refreshColdStartReport());
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        setState(() {});
        unawaited(_refreshColdStartReport());
      }
    });
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _packageInfo = info);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshColdStartReport() async {
    final report = await AdColdStartEligibility.evaluate();
    if (!mounted) return;
    setState(() => _coldStartReport = report);
  }

  Future<void> _validateZones() async {
    setState(() => _zoneValidating = true);
    final rows = await ZoneValidator.instance.validateAll();
    if (!mounted) return;
    setState(() {
      _zoneResults = rows;
      _zoneValidating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lp = LevelPlayAdService.instance;
    final cache = AdsterraNativeCache.instance;
    final lastErr = lp.lastLoadError;

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg2,
        foregroundColor: context.txt,
        title: const Text('Ad diagnostics'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Device', [
            'Fingerprint: ${AdSafetyService.instance.deviceFingerprint}',
            'Install ID: ${AdSafetyService.instance.installId}',
          ]),
          _section('LevelPlay SDK', [
            'Package: unity_levelplay_mediation 9.2.0',
            'Init: ${lp.isInitialized}',
            'Last init error: ${lp.lastInitError ?? '—'}',
            'Last load error: ${lastErr != null ? '${lastErr.errorCode} ${lastErr.errorMessage}' : '—'}',
            'Interstitial in flight: ${lp.isInterstitialLoadInFlight}',
            'Rewarded unit: ${AdConfig.hasLevelPlayRewardedUnit}',
            'Rewarded ready: ${lp.isRewardedReady}',
            'Rewarded in flight: ${lp.isRewardedLoadInFlight}',
          ]),
          _section('Fill rate (1h)', [
            'Interstitial: ${(AdHealthMonitor.instance.getFillRate('interstitial') * 100).toStringAsFixed(1)}%',
          ]),
          _section('Recent load attempts', [
            for (final a in AdHealthMonitor.instance.allRecent(limit: 10))
              '${a.at.toIso8601String().substring(11, 19)} '
              '${a.format} ${a.result}'
              '${a.errorCode != null ? ' (${a.errorCode})' : ''}',
          ]),
          _section('Adsterra cache', [
            'Hits: ${cache.hits}',
            'Misses: ${cache.misses}',
            'Hit rate: ${(cache.hitRate * 100).toStringAsFixed(1)}%',
          ]),
          _section('Build defines (keys only)', [
            AdConfig.dumpRedacted(),
          ]),
          if (_coldStartReport != null)
            _section('Post-splash promo (cold start)', [
              _coldStartReport!.logSummary,
              'LevelPlay: ${_coldStartReport!.canShowLevelPlay}',
              'Adsterra: ${_coldStartReport!.canShowAdsterra}',
              'House fallback: ${_coldStartReport!.canShowHousePromo}',
              'capLocalOnly: ${AdConfig.capLocalOnlyEffective}',
              'blocksCapRelease: ${ServerCap.instance.blocksAdsInRelease}',
              for (final b in _coldStartReport!.blockers)
                '${b.codeName}: ${b.message}',
            ]),
          if (AdConfig.diagnosticsEnabled) ...[
            if (AdConfig.hasLevelPlayRewardedUnit) ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: AdManager.instance.adsEnabled
                    ? () async {
                        final earned = await AdManager.instance.showRewarded(
                          trigger: 'diagnostics_test',
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              earned
                                  ? 'Rewarded complete — reward earned'
                                  : 'Rewarded no-fill or dismissed',
                            ),
                          ),
                        );
                      }
                    : null,
                child: const Text('Test rewarded ad'),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _zoneValidating ? null : _validateZones,
              child: Text(
                _zoneValidating ? 'Validating zones…' : 'Validate All Zones',
              ),
            ),
            if (_zoneResults.isNotEmpty)
              _section('Zone validation', [
                for (final z in _zoneResults)
                  '${z.network} ${z.placement} ${z.zoneId}: '
                  '${z.result} (${z.latencyMs}ms) ${z.formatDetected}',
              ]),
          ],
          if (_packageInfo != null)
            _section('App', [
              'Version ${_packageInfo!.version}+${_packageInfo!.buildNumber}',
            ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> lines) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GF.head(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                style: GF.body(fontSize: 11, height: 1.35),
              ),
            ),
        ],
      ),
    );
  }
}
