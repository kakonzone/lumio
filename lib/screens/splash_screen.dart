import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ads/ad_manager.dart';
import '../provider/app_provider.dart';
import '../services/ad_consent_service.dart';
import '../widgets/ad_consent_dialog.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// Splash: logo visible → consent (first launch) → home. Catalog loads in background.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const logoAsset = 'assets/images/lumio_sports_logo.webp';

  /// Minimum time splash stays on screen so branding is visible.
  static const brandingMinMs = 900;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_start());
    });
  }

  Future<void> _start() async {
    try {
      await _startInternal().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          // ignore: avoid_print
          print('[Splash] timed out — opening home');
        },
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('[Splash] error: $e\n$st');
    }
    if (!mounted) return;
    // ignore: avoid_print
    print('[Splash] pushReplacementNamed /home');
    Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _startInternal() async {
    await AdConsentService.instance.load();
    unawaited(AdConsentService.instance.applyStoredConsentToSdk());
    AdConsentService.instance.markSplashConsentGateSatisfied();
    if (!mounted) return;

    if (AdConsentService.instance.needsConsentPrompt) {
      // ignore: avoid_print
      print('[AdConsent] showing first-launch dialog');
      await AdConsentDialog.showIfNeeded(context);
      if (!mounted) return;
    }

    await Future<void>.delayed(
      const Duration(milliseconds: SplashScreen.brandingMinMs),
    );
    if (!mounted) return;

    AdManager.instance.scheduleBackgroundEngineAfterSplash();
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
              const SizedBox(height: 24),
              Text(
                'LUMIO SPORTS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent.withValues(alpha: 0.9),
                  letterSpacing: 3,
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
