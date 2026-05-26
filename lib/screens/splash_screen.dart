import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ads/ad_manager.dart';
import '../provider/app_provider.dart';
import '../services/ad_consent_service.dart';
import '../services/ad_trigger_manager.dart';
import '../widgets/ad_consent_dialog.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// Facebook-style splash: consent gate → branding load → ad preload.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const logoAsset = 'assets/images/lumio_sports_logo.png';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final prov = context.read<AppProvider>();

    // 1. Consent before any ad SDK init or splash ad timer.
    await AdConsentService.instance.load();
    await AdConsentService.instance.applyStoredConsentToSdk();
    AdConsentService.instance.markSplashConsentGateSatisfied();
    if (!mounted) return;
    if (AdConsentService.instance.needsConsentPrompt) {
      // ignore: avoid_print
      print('[AdConsent] showing first-launch dialog');
    }
    await AdConsentDialog.showIfNeeded(context);
    if (!mounted) return;

    // 2. Branding + initial data (parallel).
    final minWait = Future.delayed(const Duration(milliseconds: 2400));
    final dataWait = _waitForInitialLoad(prov);
    await Future.wait([minWait, dataWait]);
    if (!mounted) return;

    // 3. splashMinMsBeforeAds from consent resolution (see markConsentResolved).
    await AdTriggerManager.instance.waitUntilAdsEligible();
    if (!mounted) return;
    // ignore: avoid_print
    print('[AdConsent] splash ad gate open — preload may call LevelPlay.init');

    await AdManager.instance.preloadFromSplash();
    if (!mounted) return;
    await AdManager.instance.showColdStartAppOpen();
    if (!mounted) return;
    await AdManager.instance.showSplashDirectLinkIfAllowed();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _waitForInitialLoad(AppProvider prov) async {
    const maxWait = Duration(seconds: 8);
    final deadline = DateTime.now().add(maxWait);
    while (mounted && DateTime.now().isBefore(deadline)) {
      if (!prov.channelsLoading && !prov.matchesLoading) return;
      await Future.delayed(const Duration(milliseconds: 120));
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
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
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
