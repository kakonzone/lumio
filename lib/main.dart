import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'config/ad_config.dart';
import 'ads/ad_manager.dart';
import 'widgets/ad_banner_widget.dart';
import 'widgets/adsterra_overlay_widget.dart';
import 'ads/adsterra/adsterra_popunder.dart';
import 'core/shell_scope.dart';
import 'theme/app_theme.dart';
import 'screens/tv_screen.dart';
import 'screens/news_screen.dart';
import 'screens/other_screens.dart';
import 'screens/player_screen.dart';
import 'screens/ads_privacy_screen.dart';
import 'screens/dev_diagnostics_screen.dart';
import 'ads/adsterra/adsterra_native_cache.dart';
import 'services/ironsource_service.dart';
import 'screens/category_channels_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/app_drawer.dart';
import 'provider/app_provider.dart';
import 'utils/debug_log.dart';
import 'services/lumio_audio_service.dart';
import 'services/user_preferences.dart';
import 'security/security_manager.dart';
import 'services/ad_safety_service.dart';
import 'services/firebase_bootstrap.dart';
import 'services/notification_service.dart';
import 'widgets/main_shell_bottom_nav.dart';
import 'widgets/ads_debug_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint(AdConfig.dumpRedacted());
  if (!kReleaseMode && AdConfig.blockAdsInThisBuild) {
    debugPrint(
      '[AdConfig] ⚠️  WARNING: no dart-defines detected. Ads will not load.',
    );
    debugPrint('[AdConfig] ⚠️  Run via: ./scripts/flutter_run_with_ads.sh');
    debugPrint(
      '[AdConfig] ⚠️  Or: flutter run --dart-define-from-file=secrets.json',
    );
  }
  MediaKit.ensureInitialized();
  await SecurityManager.instance.initialize();
  await ensureLumioAudioService();
  await FirebaseBootstrap.initialize();
  AdsterraNativeCache.registerConsentListener();
  if (FirebaseBootstrap.isInitialized) {
    await AdSafetyService.instance.prefetchRemoteConfig();
  }
  await NotificationService.initialize();
  if (Platform.isAndroid) {
    await NotificationService.requestPermissions();
  }
  await UserPreferences.ensureInit();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: const LumioApp(),
    ),
  );
}

class LumioApp extends StatelessWidget {
  const LumioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final isDark = prov.isDark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));
    return MaterialApp(
      title: 'Lumio',
      debugShowCheckedModeBanner: false,
      theme: prov.isDark ? AppTheme.dark : AppTheme.light,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            if (child != null) child,
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AdsDebugBanner(),
            ),
          ],
        );
      },
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return PageRouteBuilder(
              settings: settings,
              pageBuilder: (_, __, ___) => const SplashScreen(),
            );
          case '/home':
            return PageRouteBuilder(
              settings: settings,
              pageBuilder: (_, __, ___) => const MainShell(),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 450),
            );
          default:
            return _onGenerateRoute(settings);
        }
      },
    );
  }

  static Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case PlayerScreen.routeName:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => PlayerScreen(
            streamUrl: args?['streamUrl'] as String? ?? '',
            title: args?['title'] as String? ?? '',
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}

// ═════════════════════════════════════════════════════════════
// MAIN SHELL — Bottom Nav + Drawer (আগের মতো)
// ═════════════════════════════════════════════════════════════
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _navIdx = 0;
  /// Index into [AppDrawerDestination] (int avoids hot-reload type mismatch after drawer refactor).
  int _drawerSelectedIndex = 0;
  int _lastNavIdx = 0;

  AppDrawerDestination get _drawerSelected {
    final values = AppDrawerDestination.values;
    final i = _drawerSelectedIndex;
    if (i >= 0 && i < values.length) return values[i];
    return AppDrawerDestination.allChannels;
  }

  void _setDrawerSelected(AppDrawerDestination dest) {
    _drawerSelectedIndex = dest.index;
  }

  static const _screens = [
    TvScreen(),
    SportsScreen(),
    LiveScreen(),
    NewsScreen(),
    CategoriesScreen(),
  ];

  void _openDrawer() {
    // #region agent log
    agentDebugLog(
      location: 'main.dart:_openDrawer',
      message: 'drawer open requested',
      hypothesisId: 'H-drawer',
      data: {
        'hasScaffoldKey': _scaffoldKey.currentState != null,
        'isDrawerOpen': _scaffoldKey.currentState?.isDrawerOpen ?? false,
      },
    );
    // #endregion
    _scaffoldKey.currentState?.openDrawer();
  }

  void _onDrawerDestination(AppDrawerDestination dest) {
    Navigator.pop(context);
    setState(() => _setDrawerSelected(dest));

    switch (dest) {
      case AppDrawerDestination.allChannels:
        setState(() => _navIdx = 0);
        return;
      case AppDrawerDestination.sports:
        setState(() => _navIdx = 1);
        unawaited(AdManager.instance.onSportsTabSelected());
        return;
      case AppDrawerDestination.entertainment:
      case AppDrawerDestination.kDrama:
      case AppDrawerDestination.movies:
        final cat = dest.categoryName!;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CategoryChannelsScreen(
              categoryName: cat,
              categoryIcon: _categoryDrawerEmoji(cat),
            ),
          ),
        );
        return;
    }
  }

  static String _categoryDrawerEmoji(String cat) => switch (cat) {
        'Entertainment' => '🎭',
        'KDrama' => '🇰🇷',
        'Movies' => '🎬',
        _ => '📺',
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AdManager.instance.maybeShowPopunder());
      if (!AdManager.instance.adsEnabled && AdConfig.hasMonetizationConfig) {
        unawaited(AdManager.instance.init());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      LevelPlayAdService.instance.onAppForeground();
    }
  }

  Future<bool> _onWillPop() async {
    if (_navIdx != 0) {
      setState(() => _navIdx = 0);
      return false;
    }
    final shown = await AdManager.instance.onExitIntent();
    return !shown;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    return ShellScope(
      scaffoldKey: _scaffoldKey,
      openDrawer: _openDrawer,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final exit = await _onWillPop();
          if (exit && context.mounted) {
            SystemNavigator.pop();
          }
        },
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: context.bg,
          drawer: LumioAppDrawer(
            selected: _drawerSelected,
            onDestinationSelected: _onDrawerDestination,
            onPrivacyTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdsPrivacyScreen(),
                ),
              );
            },
            onToggleTheme: () {
              Navigator.pop(context);
              context.read<AppProvider>().toggleTheme();
            },
            onDiagnosticsTap: AdConfig.diagnosticsEnabled
                ? () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DevDiagnosticsScreen(),
                      ),
                    );
                  }
                : null,
          ),
          body: Stack(
            children: [
              IndexedStack(index: _navIdx, children: _screens),
              if (AdManager.instance.adsEnabled)
                const Positioned(
                  left: 0,
                  bottom: 0,
                  width: 1,
                  height: 1,
                  child: AdsterraPopunderHost(),
                ),
            ],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (AdManager.instance.adsEnabled) ...[
                if (_navIdx == 0 && AdManager.instance.levelPlayReady)
                  const AdBannerWidget(placementName: 'home_bottom'),
                const AdsterraOverlayWidget(),
              ],
              MainShellBottomNav(
                currentIndex: _navIdx,
                liveChannelCount: prov.liveChannels.length,
                onTap: (idx) {
                  if (idx == 1 && _lastNavIdx != 1) {
                    unawaited(AdManager.instance.onSportsTabSelected());
                  }
                  setState(() {
                    _lastNavIdx = _navIdx;
                    _navIdx = idx;
                    if (idx == 0) {
                      _setDrawerSelected(AppDrawerDestination.allChannels);
                    } else if (idx == 1) {
                      _setDrawerSelected(AppDrawerDestination.sports);
                    }
                  });
                  if (idx == 3) prov.ensureMatchesLoaded();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

}
