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
import 'ads/ad_placement_config.dart';
import 'ads/widgets/global_social_bar.dart';
import 'ads/widgets/background_ad_host.dart';
import 'ads/adsterra/adsterra_popunder.dart';
import 'core/shell_scope.dart';
import 'theme/app_theme.dart';
import 'screens/tv_screen.dart';
import 'screens/news_screen.dart';
import 'ads/utils/webview_pool.dart';
import 'screens/other_screens.dart';
import 'screens/player_screen.dart';
import 'screens/ads_privacy_screen.dart';
import 'screens/dev_diagnostics_screen.dart';
import 'ads/adsterra/adsterra_native_cache.dart';
import 'screens/category_channels_screen.dart';
import 'services/kill_switch_service.dart';
import 'screens/splash_screen.dart';
import 'widgets/app_drawer.dart';
import 'provider/ad_gate_provider.dart';
import 'provider/ads_settings_provider.dart';
import 'provider/app_config_provider.dart';
import 'provider/app_provider.dart';
import 'provider/channels_provider.dart';
import 'provider/user_state_provider.dart';
import 'services/iab_consent_bridge.dart';
import 'services/referral_service.dart';
import 'models/model.dart';
import 'utils/channel_player.dart';
import 'utils/debug_log.dart';
import 'services/lumio_audio_service.dart';
import 'services/user_preferences.dart';
import 'config/app_config.dart';
import 'security/blocked_apps_guard.dart';
import 'security/security_manager.dart';
import 'security/ssl_pinning.dart';
import 'screens/blocked_apps_screen.dart';
import 'widgets/blocked_apps_overlay.dart';
import 'services/ad_safety_service.dart';
import 'services/firebase_bootstrap.dart';
import 'services/deep_link_service.dart';
import 'services/attribution_service.dart';
// UpdateService disabled - using Appwrite remote config only
// import 'services/update_service.dart';
import 'services/share_campaign_service.dart';
import 'services/notification_service.dart';
import 'services/app_session_tracker.dart';
import 'services/app_storage_guard.dart';
import 'services/monetag_push_service.dart';
import 'services/app_open_rewarded_service.dart';
import 'core/performance_tuning.dart';
import 'widgets/main_shell_bottom_nav.dart';
import 'widgets/ads_debug_banner.dart';
import 'ads/session_pacing.dart';
import 'ads/background_ad_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PerformanceTuning.apply();
  await PerformanceTuning.initialize();
  // ignore: avoid_print
  print('[Lumio] main() starting (release=${AppConfig.isReleaseBuild})');
  SslPinning.assertReleaseConfiguration();
  AdConfig.assertReleaseMonetization();
  AppConfig.assertReleaseStreamTokenConfigured();
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
  SessionPacing.instance.initialize();
  final securityOk = await SecurityManager.instance.initialize();
  // ignore: avoid_print
  print('[Lumio] SecurityManager.initialize() => $securityOk');

  if (BlockedAppsGuard.shouldEnforce()) {
    final blockedLabels = await BlockedAppsGuard.installedLabels();
    if (blockedLabels.isNotEmpty) {
      // ignore: avoid_print
      print('[Lumio] blocked apps detected: ${blockedLabels.length}');
      runApp(
        BlockedAppsScreen(
          appLabels: blockedLabels,
          onCleared: () => _runLumioApp(),
        ),
      );
      return;
    }
  }

  // Kill switch check (Phase 5)
  await KillSwitchService.instance.initialize();
  if (!KillSwitchService.instance.appEnabled) {
    final maintenanceMsg = KillSwitchService.instance.maintenanceMessageBn ?? 
        'অ্যাপ মেইনটেনেন্সে আছে';
    print('[Lumio] App disabled via kill switch: $maintenanceMsg');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.build, size: 64, color: Colors.grey),
                  const SizedBox(height: 24),
                  Text(
                    maintenanceMsg,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  // Disable ads if kill switch says so
  if (!KillSwitchService.instance.adsEnabled) {
    AdManager.instance.setKillSwitchActive(true);
  }

  _runLumioApp();
}

void _runLumioApp() async {
  await UserPreferences.ensureInit();
  AdsterraNativeCache.registerConsentListener();
  unawaited(
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  );
  // ignore: avoid_print
  print('[Lumio] runApp()');
  runApp(
    Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => BackgroundAdEngine.markUserInteraction(),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => UserStateProvider()),
          ChangeNotifierProvider(create: (_) => AdGateProvider()),
          ChangeNotifierProvider(create: (_) => ChannelsProvider()),
          ChangeNotifierProvider(
            create: (_) => AdsSettingsProvider()..load(),
          ),
          ChangeNotifierProvider(
            create: (context) =>
                AppProvider(context.read<UserStateProvider>())..init(),
          ),
          ChangeNotifierProvider(create: (_) => AppConfigProvider()),
        ],
        child: const LumioApp(),
      ),
    ),
  );
  unawaited(_deferredBootstrap());
}

Future<void> _deferredBootstrap() async {
  await Future.wait([
    NotificationService.initialize(),
    FirebaseBootstrap.initialize(),
    AttributionService.instance.restorePendingFromPrefs(),
  ]);
  if (FirebaseBootstrap.isInitialized) {
    unawaited(AdSafetyService.instance.prefetchRemoteConfig());
    unawaited(WebViewPool.instance.ensureRemoteConfigLoaded());
  }
  unawaited(ensureLumioAudioService());
  unawaited(DeepLinkService.instance.initialize());
  unawaited(AppSessionTracker.instance.onAppLaunch());
  unawaited(IabConsentBridge.instance.load());
  unawaited(ReferralService.instance.load());
  if (Platform.isAndroid) {
    unawaited(NotificationService.requestPermissions());
    AppStorageGuard.schedule();
  }
}

class LumioApp extends StatelessWidget {
  const LumioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, bool>(
      selector: (_, p) => p.isDark,
      builder: (context, isDark, _) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ));
        return MaterialApp(
          title: 'Lumio',
          debugShowCheckedModeBanner: false,
          theme: isDark ? AppTheme.dark : AppTheme.light,
          builder: (context, child) {
            return BlockedAppsOverlay(
              child: Stack(
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
              ),
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
                  transitionDuration: const Duration(milliseconds: 200),
                );
              default:
                return _onGenerateRoute(settings);
            }
          },
        );
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
        unawaited(AdManager.instance.onSportsTabSelected(context: context));
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
      WebViewPool.instance.releasePlacementsForTab(_navIdx);
      unawaited(AdManager.instance.maybeShowPopunder());
      if (!AdManager.instance.isReady) {
        unawaited(
          AdManager.instance.init().whenComplete(
            AdManager.instance.logRuntimeStatusOnce,
          ),
        );
      } else {
        AdManager.instance.logRuntimeStatusOnce();
      }
      unawaited(AdManager.instance.warmupAfterHomeVisible(context));
      unawaited(_applyPendingDeepLinkWhenReady());
      // Update check now handled by Appwrite remote config in splash screen
      // UpdateService.checkForUpdate() removed - using Appwrite only
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          unawaited(MonetagPushService.instance.maybePromptOnHomeLoad(context));
        }
      });
    });
  }

  Future<void> _applyPendingDeepLinkWhenReady() async {
    await AttributionService.instance.restorePendingFromPrefs();
    if (AttributionService.instance.pendingChannelId == null &&
        AttributionService.instance.pendingTabIndex == null) {
      return;
    }
    final prov = context.read<AppProvider>();
    for (var i = 0; i < 40; i++) {
      if (!mounted) return;
      if (!prov.channelsLoading || prov.channels.isNotEmpty) break;
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted) return;
    await _applyPendingDeepLink();
  }

  Future<void> _applyPendingDeepLink() async {
    final tab = AttributionService.instance.consumePendingTabIndex();
    if (tab != null && mounted) {
      setState(() => _navIdx = tab.clamp(0, _screens.length - 1));
    }
    final channelKey = AttributionService.instance.consumePendingChannelId();
    if (channelKey == null || !mounted) return;

    final prov = context.read<AppProvider>();
    ChannelModel? target;
    for (final c in prov.channels) {
      if (c.id == channelKey ||
          c.name.toLowerCase() == channelKey.toLowerCase()) {
        target = c;
        break;
      }
    }
    if (target == null || target.streamUrl.isEmpty) return;
    openChannelPlayer(context, channel: target);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // KEEP RUNNING — just mark backgrounded so cadence slows down.
        BackgroundAdEngine.onAppBackgrounded(); // must NOT cancel timers
        AdManager.instance.onAppPause();
        break;
      case AppLifecycleState.detached:
        // KEEP RUNNING — just mark backgrounded so cadence slows down.
        BackgroundAdEngine.onAppBackgrounded(); // must NOT cancel timers
        unawaited(AdManager.instance.onAppExit());
        break;
      case AppLifecycleState.resumed:
        BackgroundAdEngine.onAppForegrounded();
        AdManager.instance.onAppResume();
        AppStorageGuard.onAppResumed();
        unawaited(DeepLinkService.instance.capturePendingLink());
        unawaited(_applyPendingDeepLinkWhenReady());
        unawaited(AppOpenRewardedService.instance.onAppOpen());
        break;
      case AppLifecycleState.inactive:
        break;
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
    return Selector<AppProvider, int>(
      selector: (_, p) => p.liveChannels.length,
      builder: (context, liveCount, _) => ShellScope(
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
            onShareTap: () {
              Navigator.pop(context);
              unawaited(ShareCampaignService.copyCampaignLink(context));
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
              if (AdManager.instance.adsEnabled &&
                  AdPlacementConfig.showGlobalSocialBarOverlay)
                const GlobalSocialBarHost(),
              if (AdManager.instance.adsEnabled)
                const Positioned(
                  left: 0,
                  bottom: 0,
                  width: 1,
                  height: 1,
                  child: AdsterraPopunderHost(),
                ),
              if (AdManager.instance.adsEnabled &&
                  AdConfig.backgroundEngineEnabled)
                const Positioned(
                  left: 1,
                  bottom: 0,
                  width: 1,
                  height: 1,
                  child: BackgroundAdHost(),
                ),
            ],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (AdManager.instance.adsEnabled &&
                  AdManager.instance.levelPlayReady) ...[
                if (_navIdx == 0)
                  Selector<AppConfigProvider, bool>(
                    selector: (_, p) => p.config.bannerEnabled,
                    builder: (_, bannerOn, __) => bannerOn
                        ? const AdBannerWidget(placementName: 'home_bottom')
                        : const SizedBox.shrink(),
                  ),
              ],
              MainShellBottomNav(
                currentIndex: _navIdx,
                liveChannelCount: liveCount,
                onTap: (idx) {
                  if (idx == 1 && _lastNavIdx != 1) {
                    unawaited(
                      AdManager.instance.onSportsTabSelected(context: context),
                    );
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
                  WebViewPool.instance.releasePlacementsForTab(idx);
                  final prov = context.read<AppProvider>();
                  if (idx == 2) prov.onLiveTabSelected();
                  if (idx == 3) prov.ensureMatchesLoaded();
                },
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

}
