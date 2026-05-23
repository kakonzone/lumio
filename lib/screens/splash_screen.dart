import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// Facebook-style splash: centered logo + loading, then fade to home.
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
    final minWait = Future.delayed(const Duration(milliseconds: 2400));
    final dataWait = _waitForInitialLoad(prov);
    await Future.wait([minWait, dataWait]);
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
