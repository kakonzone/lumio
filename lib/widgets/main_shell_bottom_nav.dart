import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio_tv/theme/app_theme.dart';

/// Bottom navigation for Home · Sports · Live · News · Categories.
class MainShellBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int? liveChannelCount;

  const MainShellBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.liveChannelCount,
  });

  static const _items = [
    _NavSpec(Icons.home_rounded, Icons.home_filled, 'Home', false),
    _NavSpec(Icons.sports_soccer_rounded, Icons.sports_soccer, 'Sports', true),
    _NavSpec(Icons.sensors_rounded, Icons.sensors, 'Live', true),
    _NavSpec(Icons.newspaper_rounded, Icons.newspaper, 'News', false),
    _NavSpec(Icons.grid_view_rounded, Icons.grid_view, 'Browse', false),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.cardSurface,
        border: Border(top: BorderSide(color: context.brd)),
        boxShadow: [
          BoxShadow(
            color: context.shadowColor,
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;
            return SizedBox(
              height: compact ? 62 : 66,
              child: Row(
                children: List.generate(_items.length, (i) {
                  final spec = _items[i];
                  final active = currentIndex == i;
                  final showBadge = spec.liveHint &&
                      !active &&
                      (liveChannelCount ?? 0) > 0 &&
                      i == 2;
                  return Expanded(
                    child: _NavTile(
                      spec: spec,
                      active: active,
                      compact: compact,
                      showLiveBadge: showBadge,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTap(i);
                      },
                      isDark: isDark,
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NavSpec {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool liveHint;

  const _NavSpec(this.icon, this.activeIcon, this.label, this.liveHint);
}

class _NavTile extends StatelessWidget {
  final _NavSpec spec;
  final bool active;
  final bool compact;
  final bool showLiveBadge;
  final VoidCallback onTap;
  final bool isDark;

  const _NavTile({
    required this.spec,
    required this.active,
    required this.compact,
    required this.showLiveBadge,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.accent.withValues(alpha: 0.12),
        highlightColor: AppColors.accent.withValues(alpha: 0.06),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 12,
                vertical: compact ? 5 : 6,
              ),
              decoration: BoxDecoration(
                gradient: active
                    ? LinearGradient(
                        colors: isDark
                            ? [
                                AppColors.accent.withValues(alpha: 0.35),
                                AppColors.accent.withValues(alpha: 0.12),
                              ]
                            : [
                                AppColors.accent.withValues(alpha: 0.22),
                                AppColors.accentLight,
                              ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : null,
                color: active ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: active
                    ? Border.all(
                        color: AppColors.accent.withValues(alpha: 0.45),
                        width: 1,
                      )
                    : null,
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    active ? spec.activeIcon : spec.icon,
                    size: active ? 26 : 24,
                    color: active ? AppColors.accent : context.txt3,
                  ),
                  if (showLiveBadge)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.liveRed,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.cardSurface,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                spec.label,
                style: GF.body(
                  fontSize: compact ? 9 : 10,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? AppColors.accent : context.txt3,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
              ),
            ),
            SizedBox(
              height: active ? 3 : 3,
              child: active
                  ? Container(
                      width: 16,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
