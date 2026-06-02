import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ads/ad_manager.dart';
import '../provider/app_provider.dart';
import '../services/ad_consent_service.dart';
import '../widgets/ad_consent_dialog.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// Fast splash: consent (first launch only) → brief logo → home. Ads warm after home paints.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const logoAsset = 'assets/images/lumio_sports_logo.webp';

  /// Minimum branding flash so the logo does not flicker.
  static const brandingMinMs = 350;

  /// Do not block home longer than this waiting on channel index.
  static const channelWaitMaxMs = 500;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    var navigateHome = true;
    try {
      navigateHome = await _startInternal().timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          // ignore: avoid_print
          print('[Splash] timed out — opening home');
          return true;
        },
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('[Splash] error: $e\n$st');
    }
    if (!mounted) return;
    if (navigateHome) {
      // ignore: avoid_print
      print('[Splash] pushReplacementNamed /home');
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<bool> _startInternal() async {
    final prov = context.read<AppProvider>();

    await AdConsentService.instance.load();
    unawaited(AdConsentService.instance.applyStoredConsentToSdk());
    AdConsentService.instance.markSplashConsentGateSatisfied();
    if (!mounted) return true;

    if (AdConsentService.instance.needsConsentPrompt) {
      // ignore: avoid_print
      print('[AdConsent] showing first-launch dialog');
      await AdConsentDialog.showIfNeeded(context);
      if (!mounted) return true;
    }

    await Future.wait([
      Future<void>.delayed(
        const Duration(milliseconds: SplashScreen.brandingMinMs),
      ),
      _waitForInitialLoad(prov),
    ]);
    if (!mounted) return true;

    AdManager.instance.scheduleBackgroundEngineAfterSplash();
    return true;
  }

  Future<void> _waitForInitialLoad(AppProvider prov) async {
    final deadline = DateTime.now().add(
      const Duration(milliseconds: SplashScreen.channelWaitMaxMs),
    );
    while (mounted && DateTime.now().isBefore(deadline)) {
      if (!prov.channelsLoading) return;
      await Future.delayed(const Duration(milliseconds: 40));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;
    final bg = isDark ? AppColors.bgDark : const Color(0xFF000000);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              Image.asset(
                SplashScreen.logoAsset,
                width: Responsive.w(context, 70).clamp(200.0, 280.0),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Column(
                  children: [
                    Text(
                      'LUMIO',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: context.txt,
                      ),
                    ),
                    const Text(
                      'SPORTS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
