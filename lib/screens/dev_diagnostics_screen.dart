import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../ads/adsterra/adsterra_native_cache.dart';
import '../config/ad_config.dart';
import '../services/ad_health_monitor.dart';
import '../services/ad_safety_service.dart';
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

  @override
  void initState() {
    super.initState();
    unawaited(_loadPackageInfo());
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
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
            'Rewarded in flight: ${lp.isRewardedLoadInFlight}',
            'Interstitial in flight: ${lp.isInterstitialLoadInFlight}',
          ]),
          _section('Fill rate (1h)', [
            'Interstitial: ${(AdHealthMonitor.instance.getFillRate('interstitial') * 100).toStringAsFixed(1)}%',
            'Rewarded: ${(AdHealthMonitor.instance.getFillRate('rewarded') * 100).toStringAsFixed(1)}%',
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
