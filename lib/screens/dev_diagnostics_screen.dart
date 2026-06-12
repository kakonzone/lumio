import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../ads/ad_cold_start_eligibility.dart';
import '../ads/ad_manager.dart';
import '../ads/adsterra/adsterra_native_cache.dart';
import '../ads/diagnostics/zone_validator.dart';
import '../config/ad_config.dart';
import '../services/ad_health_monitor.dart';
import '../services/ad_safety_service.dart';
import '../services/server_cap.dart';
import '../services/unity_ads_service.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/colors.dart';

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
  Map<String, double> _todayRevenue = {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadPackageInfo());
    unawaited(_refreshColdStartReport());
    unawaited(_loadRevenueData());
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        setState(() {});
        unawaited(_refreshColdStartReport());
        unawaited(_loadRevenueData());
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

  Future<void> _loadRevenueData() async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final revenue = <String, double>{};
      
      // Get all keys that start with revenue_estimate for today
      final keys = prefs.getKeys().where((k) => k.startsWith('revenue_estimate_$today\_'));
      for (final key in keys) {
        final value = prefs.getDouble(key) ?? 0.0;
        // Extract placement from key (format: revenue_estimate_YYYY-MM-DD_placement)
        final parts = key.split('_');
        if (parts.length >= 4) {
          final placement = parts.sublist(3).join('_');
          revenue[placement] = value;
        }
      }
      
      if (mounted) {
        setState(() {
          _todayRevenue = revenue;
        });
      }
    } catch (e) {
      debugPrint('[DevDiagnostics] Revenue data load error: $e');
    }
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
    final ua = UnityAdsService.instance;
    final cache = AdsterraNativeCache.instance;

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
          _section('Unity Ads SDK', [
            'Package: unity_ads_plugin',
            'Init: ${ua.isInitialized}',
            'Interstitial ready: ${ua.isInterstitialReady}',
            'Rewarded ready: ${ua.isRewardedReady}',
          ]),
          _section('Fill rate (1h)', [
            'Interstitial: ${(AdHealthMonitor.instance.getFillRate('interstitial') * 100).toStringAsFixed(1)}%',
          ]),
          _section('Revenue estimate (today)', [
            if (_todayRevenue.isEmpty)
              'No revenue data yet'
            else
              for (final entry in _todayRevenue.entries)
                '${entry.key}: \$${entry.value.toStringAsFixed(4)}',
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
              'Unity: ${_coldStartReport!.canShowUnity}',
              'Adsterra: ${_coldStartReport!.canShowAdsterra}',
              'House fallback: ${_coldStartReport!.canShowHousePromo}',
              'capLocalOnly: ${AdConfig.capLocalOnlyEffective}',
              'blocksCapRelease: ${ServerCap.instance.blocksAdsInRelease}',
              for (final b in _coldStartReport!.blockers)
                '${b.codeName}: ${b.message}',
            ]),
          if (AdConfig.diagnosticsEnabled) ...[
            if (AdConfig.hasUnityConfig) ...[
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
              color: AppTokens.accent,
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
