import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'core/shell_scope.dart';
import 'theme/app_theme.dart';
import 'screens/tv_screen.dart';
import 'screens/other_screens.dart';
import 'screens/player_screen.dart';
import 'screens/splash_screen.dart';
import 'provider/app_provider.dart';
import 'utils/debug_log.dart';
import 'services/lumio_audio_service.dart';
import 'widgets/main_shell_bottom_nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await ensureLumioAudioService();
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

class _MainShellState extends State<MainShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _navIdx = 0;
  int _drawerSelected = 0;

  static const _screens = [
    TvScreen(),
    SportsScreen(),
    LiveScreen(),
    NewsScreen(),
    CategoriesScreen(),
  ];

  static const _drawerItems = [
    {'icon': '📺', 'name': 'All Channels', 'count': '2.4k'},
    {'icon': '⚽', 'name': 'Sports', 'count': '142'},
    {'icon': '🇧🇩', 'name': 'Bangladesh', 'count': '38'},
    {'icon': '🇮🇳', 'name': 'India', 'count': '215'},
    {'icon': '🎬', 'name': 'Movies', 'count': '56'},
    {'icon': '🎭', 'name': 'Entertainment', 'count': '89'},
    {'icon': '🇰🇷', 'name': 'KDrama', 'count': '44'},
    {'icon': '🧒', 'name': 'Kids', 'count': '31'},
    {'icon': '🏙️', 'name': 'Kolkata', 'count': '27'},
    {'icon': '🇮🇳', 'name': 'Hindi', 'count': '96'},
    {'icon': '🇵🇰', 'name': 'Pakistan', 'count': '27'},
  ];

  /// Drawer tap → bottom nav index (Sports=1, Categories=4, else TV=0).
  static int _drawerNavIndex(int i) {
    if (i == 1) return 1;
    if (i >= 2) return 4;
    return 0;
  }

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

  void _onDrawerItem(int index) {
    setState(() {
      _drawerSelected = index;
      _navIdx = _drawerNavIndex(index);
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    return ShellScope(
      scaffoldKey: _scaffoldKey,
      openDrawer: _openDrawer,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: context.bg,
        drawer: _buildDrawer(context),
        body: IndexedStack(index: _navIdx, children: _screens),
        bottomNavigationBar: MainShellBottomNav(
          currentIndex: _navIdx,
          liveChannelCount: prov.liveChannels.length,
          onTap: (idx) {
            setState(() => _navIdx = idx);
            if (idx == 3) prov.ensureMatchesLoaded();
          },
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: context.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.brd)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: 'BarlowCondensed',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                      children: [
                        TextSpan(
                          text: 'LUMIO',
                          style: TextStyle(color: context.txt),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All Channels • Live Streaming',
                    style: TextStyle(fontSize: 11, color: context.txt3),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: _drawerItems.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: context.brd),
                itemBuilder: (ctx, i) {
                  final item = _drawerItems[i];
                  final isSelected = i == _drawerSelected;
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 2,
                    ),
                    leading: Text(
                      item['icon']!,
                      style: const TextStyle(fontSize: 16),
                    ),
                    title: Text(
                      item['name']!,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? AppColors.accent : context.txt2,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.bg3,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item['count']!,
                        style: TextStyle(fontSize: 11, color: context.txt3),
                      ),
                    ),
                    onTap: () => _onDrawerItem(i),
                  );
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.brd)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Icon(
                  context.watch<AppProvider>().isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: context.txt3,
                  size: 20,
                ),
                title: Text(
                  context.watch<AppProvider>().isDark
                      ? 'Light Mode'
                      : 'Dark Mode',
                  style: TextStyle(fontSize: 14, color: context.txt2),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.read<AppProvider>().toggleTheme();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

}
