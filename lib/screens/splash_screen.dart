import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../core/logging/safe_logger.dart';
import '../ads/ad_manager.dart';
import '../provider/app_config_provider.dart';
import '../provider/theme_provider.dart';
import '../services/ad_consent_service.dart';
import '../services/remote_channels_service.dart';
import '../services/special_link/special_link_cache.dart';
import '../widgets/remote_config_widgets.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/colors.dart' as tokens;
import '../utils/responsive.dart';
import 'generic_error_screen.dart';

/// Splash: logo visible → remote config → consent (first launch) → home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const logoAsset = 'assets/images/lumio_sports_logo.webp';

  /// Minimum time splash stays on screen so branding is visible.
  static const brandingMinMs = 1200;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_start());
    });
  }

  Future<void> _start() async {
    // Clear caches for debugging GitHub source
    if (kDebugMode) {
      RemoteChannelsService.clearCache();
      await SpecialLinkCache.instance.clearAppCatalogChannels();
    }

    var proceedToHome = true;
    try {
      proceedToHome = await _startInternal().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          SafeLogger.debug('splash',
              '[Splash] timed out — opening home (providers will load lazily)');
          return true;
        },
      );
    } catch (e, st) {
      SafeLogger.error('splash', '[Splash] error', e, st);
      if (!mounted) return;
      _didNavigate = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => GenericErrorScreen(
            title: 'Initialization Failed',
            message: 'An error occurred during app startup',
            details: e.toString(),
            onRetry: () {
              Navigator.of(context).pushReplacementNamed('/splash');
            },
          ),
        ),
      );
      return;
    }
    
    if (!mounted || _didNavigate || !proceedToHome) return;
    _didNavigate = true;
    SafeLogger.debug('splash', '[Splash] pushReplacementNamed /home');
    Navigator.of(context).pushReplacementNamed('/home');
  }

  /// Returns false when splash already navigated elsewhere (maintenance, etc.).
  Future<bool> _startInternal() async {
    // Run initialization in parallel with branding delay
    await Future.wait<void>([
      // Initialize app config (with timeout to ensure we don't block)
      context.read<AppConfigProvider>().init().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          SafeLogger.debug('splash',
              '[Splash] App config init timed out - will load lazily');
        },
      ),
      // Branding delay
      Future<void>.delayed(
        const Duration(milliseconds: SplashScreen.brandingMinMs),
      ),
      // Load ad consent in parallel
      AdConsentService.instance.load(),
    ]);

    if (!mounted) return false;

    // Apply consent and mark gate satisfied
    unawaited(AdConsentService.instance.applyStoredConsentToSdk());
    AdConsentService.instance.markSplashConsentGateSatisfied();

    final config = context.read<AppConfigProvider>().config;

    // Check maintenance mode
    if (config.maintenanceMode) {
      SafeLogger.debug(
          'splash', '[Splash] maintenance_mode active — blocking app');
      _didNavigate = true;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MaintenanceScreen(config: config),
        ),
      );
      return false;
    }

    // Check force update
    if (config.forceUpdate) {
      final packageInfo = await PackageInfo.fromPlatform();
      if (isAppVersionOlder(packageInfo.version, config.latestVersion)) {
        if (!mounted) return false;
        SafeLogger.debug(
            'splash', '[Splash] force_update required — showing dialog');
        await ForceUpdateDialog.show(context, config);
        return false;
      }
    }

    if (!mounted) return false;
    await AdConsentService.instance.setConsent(granted: true);
    //await AdConsentDialog.showIfNeeded(context);
    if (!mounted) return false;

    // App-open promo ad is now shown before splash (in AppOpenAdScreen)
    // No need to show it here anymore

    // Interstitial ad chain removed from splash screen
    // Navigate to home directly

    // Schedule background ad engine
    AdManager.instance.scheduleBackgroundEngineAfterSplash();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDark;
    final bg = isDark ? context.bg : const Color(0xFF000000);

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
                        color: tokens.AppTokens.accent,
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
                  color: tokens.AppTokens.accent.withValues(alpha: 0.9),
                  letterSpacing: 3,
                ),
              ),
              const Spacer(flex: 2),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tokens.AppTokens.accent,
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
