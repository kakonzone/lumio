import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'core/logging/safe_logger.dart';
import 'config/ad_config.dart';
import 'ads/ad_manager.dart';
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
import 'screens/splash_screen.dart';
import 'screens/app_open_promo_screen.dart';
import 'widgets/app_drawer.dart';
import 'provider/ad_gate_provider.dart';
import 'provider/ads_settings_provider.dart';
import 'provider/app_config_provider.dart';
import 'provider/app_provider.dart';
import 'provider/channel_catalog_provider.dart';
import 'provider/channels_provider.dart';
import 'provider/ui_state_provider.dart';
import 'provider/favorites_provider.dart';
import 'provider/live_events_provider.dart';
import 'provider/live_score_provider.dart';
import 'provider/news_provider.dart';
import 'provider/theme_provider.dart';
import 'provider/user_state_provider.dart';
import 'services/iab_consent_bridge.dart';
import 'utils/app_logger.dart';
import 'services/referral_service.dart';
import 'models/model.dart';
import 'utils/channel_player.dart';
import 'services/lumio_audio_service.dart';
import 'services/user_preferences.dart';
import 'config/app_config.dart';
import 'security/blocked_apps_guard.dart';
import 'security/security_manager.dart';
import 'security/security_config.dart';
import 'config/monetag_config.dart';
import 'security/ssl_pinning.dart';
import 'security/anti_clone_service.dart';
import 'security/install_watermark_service.dart';
import 'screens/blocked_apps_screen.dart';
import 'widgets/blocked_apps_overlay.dart';
import 'widgets/offline_banner.dart';
import 'services/ad_safety_service.dart';
import 'services/firebase_bootstrap.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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
import 'widgets/error_boundary.dart';
import 'ads/session_pacing.dart';
import 'ads/background_ad_engine.dart';
import 'l10n/app_localizations.dart';
import 'utils/agent_debug_log.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AgentDebugLog.init();
  // #region agent log
  AgentDebugLog.log(
    location: 'main.dart:main:entry',
    message: 'main() started',
    hypothesisId: 'E',
    data: {'kReleaseMode': kReleaseMode},
  );
  // #endregion
  await PerformanceTuning.apply();
  await PerformanceTuning.initialize();
  SafeLogger.debug('main', '[Lumio] main() starting (release=${AppConfig.isReleaseBuild})');
  // #region agent log
  AgentDebugLog.log(
    location: 'main.dart:main:pre-assertions',
    message: 'before release assertions',
    hypothesisId: 'A',
    data: {
      'monetagAnyDefine': MonetagConfig.anyDefineProvided,
      'monetagConfigured': MonetagConfig.isConfigured,
      'hasMonetization': AdConfig.hasMonetizationConfig,
      'hasStreamToken': AppConfig.hasStreamTokenBaseUrl,
    },
  );
  // #endregion
  SslPinning.assertReleaseConfiguration();
  try {
    AdConfig.assertReleaseMonetization();
    // #region agent log
    AgentDebugLog.log(
      location: 'main.dart:main:post-monetization',
      message: 'assertReleaseMonetization passed',
      hypothesisId: 'A',
    );
    // #endregion
  } catch (e, st) {
    // #region agent log
    AgentDebugLog.log(
      location: 'main.dart:main:monetization-fail',
      message: 'assertReleaseMonetization threw',
      hypothesisId: 'A',
      data: {'error': e.toString(), 'stack': st.toString().split('\n').take(3).join(' | ')},
    );
    // #endregion
    rethrow;
  }
  try {
    AppConfig.assertReleaseStreamTokenConfigured();
    // #region agent log
    AgentDebugLog.log(
      location: 'main.dart:main:post-stream-token',
      message: 'assertReleaseStreamTokenConfigured passed',
      hypothesisId: 'B',
    );
    // #endregion
  } catch (e, st) {
    // #region agent log
    AgentDebugLog.log(
      location: 'main.dart:main:stream-token-fail',
      message: 'assertReleaseStreamTokenConfigured threw',
      hypothesisId: 'B',
      data: {'error': e.toString()},
    );
    // #endregion
    rethrow;
  }
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
  // #region agent log
  AgentDebugLog.log(
    location: 'main.dart:main:post-security',
    message: 'SecurityManager.initialize completed',
    hypothesisId: 'C',
    data: {'securityOk': securityOk, 'strictMode': SecurityConfig.strictModeInRelease},
  );
  // #endregion
  SafeLogger.debug('main', '[Lumio] SecurityManager.initialize() => $securityOk');

  // Initialize new anti-clone security services
  final antiCloneOk = await AntiCloneService.instance.initialize();
  SafeLogger.debug('main', '[Lumio] AntiCloneService.initialize() => $antiCloneOk');

  final watermarkOk = await InstallWatermarkService.instance.initialize();
  SafeLogger.debug('main', '[Lumio] InstallWatermarkService.initialize() => $watermarkOk');

  // Register install with backend (in production)
  if (antiCloneOk && watermarkOk && kReleaseMode) {
    final backendUrl = String.fromEnvironment('INTEGRITY_VERIFICATION_ENDPOINT', 
      defaultValue: 'https://api.example.com');
    unawaited(
      InstallWatermarkService.instance.registerWithBackend(backendUrl).catchError((e) {
        SafeLogger.error('main', '[Lumio] Install registration failed', e);
        return false;
      })
    );
  }

  if (BlockedAppsGuard.shouldEnforce()) {
    final blockedLabels = await BlockedAppsGuard.installedLabels();
    // #region agent log
    AgentDebugLog.log(
      location: 'main.dart:main:blocked-apps',
      message: 'BlockedAppsGuard check',
      hypothesisId: 'D',
      data: {'blockedCount': blockedLabels.length},
    );
    // #endregion
    if (blockedLabels.isNotEmpty) {
      SafeLogger.debug('main', '[Lumio] blocked apps detected: ${blockedLabels.length}');
      runApp(
        BlockedAppsScreen(
          appLabels: blockedLabels,
          onCleared: () => _runLumioApp(),
        ),
      );
      return;
    }
  }

  _runLumioApp();
}

void _runLumioApp() async {
  await UserPreferences.ensureInit();
  
  // Initialize logger
  AppLogger.initialize();
  AppLogger.info('App starting up', subsystem: 'main');
  
  AdsterraNativeCache.registerConsentListener();
  unawaited(
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  );
  SafeLogger.debug('main', '[Lumio] runApp()');
  // #region agent log
  AgentDebugLog.log(
    location: 'main.dart:_runLumioApp:pre-runApp',
    message: 'calling runApp',
    hypothesisId: 'E',
  );
  // #endregion
  runApp(
    Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => BackgroundAdEngine.markUserInteraction(),
      child: MultiProvider(
        providers: [
          // New focused providers (Phase 1 - Infrastructure)
          ChangeNotifierProvider(
            create: (_) => ThemeProvider()..load(),
          ),
          ChangeNotifierProvider(
            create: (_) => FavoritesProvider()..load(),
          ),
          ChangeNotifierProvider(create: (_) => LiveScoreProvider()),
          ChangeNotifierProvider(create: (_) => NewsProvider()),
          ChangeNotifierProvider(create: (_) => LiveEventsProvider()),
          
          // Existing providers
          ChangeNotifierProvider(create: (_) => UserStateProvider()),
          ChangeNotifierProvider(create: (_) => AdGateProvider()),
          ChangeNotifierProvider(create: (_) => ChannelsProvider()),
          ChangeNotifierProvider(
            create: (_) => AdsSettingsProvider()..load(),
          ),
          ChangeNotifierProvider(create: (_) => ChannelCatalogProvider()),
          ChangeNotifierProvider(create: (_) => UiStateProvider()),
          ChangeNotifierProvider(
            create: (context) => AppProvider(
              context.read<UserStateProvider>(),
              catalogIn: context.read<ChannelCatalogProvider>(),
              uiIn: context.read<UiStateProvider>(),
            )..init(),
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

class LumioApp extends StatefulWidget {
  const LumioApp({super.key});
  @override
  State<LumioApp> createState() => _LumioAppState();
}

class _LumioAppState extends State<LumioApp> {
  bool _isDark = false;
  AppProvider? _appProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appProvider?.removeListener(_onThemeChanged);
    _appProvider = context.read<AppProvider>();
    _isDark = _appProvider!.isDark;
    _appProvider!.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _appProvider!.isDark != _isDark) {
        setState(() => _isDark = _appProvider!.isDark);
      }
    });
  }

  @override
  void dispose() {
    _appProvider?.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: _isDark ? Brightness.light : Brightness.dark,
    ));
    return MaterialApp(
      title: 'Lumio',
      debugShowCheckedModeBanner: false,
      theme: _isDark ? AppTheme.dark : AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'), // Fallback to English by default
      builder: (context, child) {
        return ErrorBoundary(
          onError: (error, stack) {
            // Log to crashlytics if available
            if (FirebaseBootstrap.isInitialized) {
              FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
            }
          },
          child: BlockedAppsOverlay(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (child != null) child,
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: OfflineBanner(),
                ),
                const Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: AdsDebugBanner(),
                ),
              ],
            ),
          ),
        );
      },
      initialRoute: '/app_open',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/app_open':
            return PageRouteBuilder(
              settings: settings,
              pageBuilder: (_, __, ___) => const AppOpenPromoScreen(),
            );
          case '/splash':
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
    SafeLogger.debug('main', 'main.dart:_openDrawer: drawer open requested (H-drawer) hasScaffoldKey=${_scaffoldKey.currentState != null} isDrawerOpen=${_scaffoldKey.currentState?.isDrawerOpen ?? false}');
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
      case AppLifecycleState.resumed:
        AdManager.instance.onAppResume();
        AppStorageGuard.onAppResumed();
        unawaited(DeepLinkService.instance.capturePendingLink());
        unawaited(_applyPendingDeepLinkWhenReady());
        unawaited(AppOpenRewardedService.instance.onAppOpen());
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        AdManager.instance.onAppPause();
        break;
      case AppLifecycleState.detached:
        unawaited(AdManager.instance.onAppExit());
        break;
      case AppLifecycleState.hidden:
        AdManager.instance.onAppPause();
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
                    AdManager.instance.unityAdsReady) ...[
                  if (_navIdx == 0)
                    // ISSUE: Replace with Unity Ads or Adsterra banner implementation
                    // See: https://github.com/your-repo/issues/XXX
                    // Unity Ads banner implementation needed
                    // Selector<AppConfigProvider, bool>(
                    //   selector: (_, p) => p.config.bannerEnabled,
                    //   builder: (_, bannerOn, __) => bannerOn
                    //       ? const AdBannerWidget(placementName: 'home_bottom')
                    //       : const SizedBox.shrink(),
                    // ),
                    const SizedBox.shrink(),
                ],
                MainShellBottomNav(
                  currentIndex: _navIdx,
                  liveChannelCount: liveCount,
                  onTap: (idx) {
                    if (idx == 1 && _lastNavIdx != 1) {
                      unawaited(
                        AdManager.instance
                            .onSportsTabSelected(context: context),
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
