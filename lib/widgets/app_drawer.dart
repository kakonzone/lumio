import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/ad_config.dart';
import '../provider/app_provider.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/colors.dart';

/// Drawer destinations — maps to home tabs or [CategoryChannelsScreen].
enum AppDrawerDestination {
  allChannels,
  sports,
  entertainment,
  kDrama,
  movies,
}

extension AppDrawerDestinationX on AppDrawerDestination {
  String? get categoryName => switch (this) {
        AppDrawerDestination.allChannels => null,
        AppDrawerDestination.sports => 'Sports',
        AppDrawerDestination.entertainment => 'Entertainment',
        AppDrawerDestination.kDrama => 'KDrama',
        AppDrawerDestination.movies => 'Movies',
      };

  IconData get icon => switch (this) {
        AppDrawerDestination.allChannels => Icons.grid_view_rounded,
        AppDrawerDestination.sports => Icons.sports_soccer_rounded,
        AppDrawerDestination.entertainment => Icons.theaters_rounded,
        AppDrawerDestination.kDrama => Icons.auto_awesome_rounded,
        AppDrawerDestination.movies => Icons.movie_rounded,
      };

  Color accentColor(BuildContext context) => switch (this) {
        AppDrawerDestination.allChannels => AppTokens.accent,
        AppDrawerDestination.sports => const Color(0xFFFF6B1A),
        AppDrawerDestination.entertainment => const Color(0xFF9C27B0),
        AppDrawerDestination.kDrama => const Color(0xFFFF4081),
        AppDrawerDestination.movies => const Color(0xFFE91E63),
      };

  String label(BuildContext context) => switch (this) {
        AppDrawerDestination.allChannels => 'All Channels',
        AppDrawerDestination.sports => 'Sports',
        AppDrawerDestination.entertainment => 'Entertainment',
        AppDrawerDestination.kDrama => 'KDrama',
        AppDrawerDestination.movies => 'Movies',
      };

  String subtitle(BuildContext context, int count) => switch (this) {
        AppDrawerDestination.allChannels =>
          count > 0 ? '$count channels' : 'Browse everything',
        AppDrawerDestination.sports =>
          count > 0 ? '$count live sports' : 'Cricket, football & more',
        AppDrawerDestination.entertainment =>
          count > 0 ? '$count channels' : 'Drama, reality & talk',
        AppDrawerDestination.kDrama =>
          count > 0 ? '$count channels' : 'Korean series & shows',
        AppDrawerDestination.movies =>
          count > 0 ? '$count channels' : 'Movies & cinema',
      };
}

/// Side navigation — categories + settings footer.
class LumioAppDrawer extends StatelessWidget {
  final AppDrawerDestination selected;
  final ValueChanged<AppDrawerDestination> onDestinationSelected;
  final VoidCallback onPrivacyTap;
  final VoidCallback onToggleTheme;
  final VoidCallback? onShareTap;
  final VoidCallback? onDiagnosticsTap;

  const LumioAppDrawer({
    super.key,
    required this.selected,
    required this.onDestinationSelected,
    required this.onPrivacyTap,
    required this.onToggleTheme,
    this.onShareTap,
    this.onDiagnosticsTap,
  });

  static int liveCount(AppProvider prov, AppDrawerDestination dest) {
    final cat = dest.categoryName;
    final list = cat == null ? prov.channels : prov.byCategory(cat);
    return list.where((c) => c.streamUrl.isNotEmpty).length;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final isDark = prov.isDark;

    return Drawer(
      backgroundColor: context.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DrawerHeader(isDark: isDark),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'BROWSE',
                style: GF.head(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: context.txt3,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final dest in AppDrawerDestination.values)
                    _DrawerNavTile(
                      destination: dest,
                      count: liveCount(prov, dest),
                      selected: selected == dest,
                      onTap: () => onDestinationSelected(dest),
                    ),
                ],
              ),
            ),
            _DrawerFooter(
              isDark: isDark,
              onPrivacyTap: onPrivacyTap,
              onToggleTheme: onToggleTheme,
              onShareTap: onShareTap,
              onDiagnosticsTap: onDiagnosticsTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  final bool isDark;

  const _DrawerHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFFFF6B1A), Color(0xFFC43E00)]
              : const [Color(0xFFFF7A2E), Color(0xFFE65100)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTokens.accent.withValues(alpha: isDark ? 0.35 : 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.live_tv_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LUMIO',
                      style: GF.head(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Live TV & Sports',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Pick a category to stream',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerNavTile extends StatelessWidget {
  final AppDrawerDestination destination;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerNavTile({
    required this.destination,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = destination.accentColor(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: context.isDark ? 0.18 : 0.12)
                  : context.bg2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? accent.withValues(alpha: 0.55) : context.brd,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(destination.icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination.label(context),
                        style: GF.body(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: selected ? context.txt : context.txt2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        destination.subtitle(context, count),
                        style: GF.body(fontSize: 11, color: context.txt3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withValues(alpha: 0.25)
                          : context.bg3,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count',
                      style: GF.body(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: selected ? accent : context.txt3,
                      ),
                    ),
                  ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded, color: accent, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerFooter extends StatefulWidget {
  final bool isDark;
  final VoidCallback onPrivacyTap;
  final VoidCallback onToggleTheme;
  final VoidCallback? onShareTap;
  final VoidCallback? onDiagnosticsTap;

  const _DrawerFooter({
    required this.isDark,
    required this.onPrivacyTap,
    required this.onToggleTheme,
    this.onShareTap,
    this.onDiagnosticsTap,
  });

  @override
  State<_DrawerFooter> createState() => _DrawerFooterState();
}

class _DrawerFooterState extends State<_DrawerFooter> {
  int _versionTapCount = 0;

  void _onVersionTap() {
    if (!AdConfig.diagnosticsEnabled || widget.onDiagnosticsTap == null) {
      return;
    }
    _versionTapCount++;
    if (_versionTapCount >= 7) {
      _versionTapCount = 0;
      widget.onDiagnosticsTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.bg2,
        border: Border(top: BorderSide(color: context.brd)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SETTINGS',
            style: GF.head(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: context.txt3,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          _FooterAction(
            icon: Icons.privacy_tip_outlined,
            label: 'Ads & privacy',
            onTap: widget.onPrivacyTap,
          ),
          _FooterAction(
            icon: widget.isDark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            label: widget.isDark ? 'Light mode' : 'Dark mode',
            onTap: widget.onToggleTheme,
          ),
          if (widget.onShareTap != null)
            _FooterAction(
              icon: Icons.share_outlined,
              label: 'Share app',
              onTap: widget.onShareTap!,
            ),
          const SizedBox(height: 12),
          Divider(height: 1, color: context.brd),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: context.txt3),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '© ${DateTime.now().year} Lumio TV',
                      style: GF.body(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.txt2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Streams are provided by third-party sources. '
                      'Lumio is not affiliated with any broadcaster or league.',
                      style: GF.body(
                        fontSize: 10,
                        color: context.txt3,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _onVersionTap,
                      child: Text(
                        'Version 1.0.0 · Made for live sports fans',
                        style: GF.body(fontSize: 10, color: context.txt3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _FooterAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FooterAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20, color: context.txt3),
      title: Text(
        label,
        style: GF.body(fontSize: 14, color: context.txt2),
      ),
      trailing:
          Icon(Icons.chevron_right_rounded, size: 18, color: context.txt3),
      onTap: onTap,
    );
  }
}
