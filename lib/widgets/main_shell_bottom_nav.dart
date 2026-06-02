import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio_tv/theme/app_theme.dart';

/// Bottom navigation for Home · Sports · Live · News · Browse.
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
    _NavSpec(
      Icons.home_rounded,
      Icons.home_filled,
      'Home',
      false,
      [Color(0xFF3949AB), Color(0xFF5C6BC0)],
    ),
    _NavSpec(
      Icons.sports_soccer_rounded,
      Icons.sports_soccer,
      'Sports',
      true,
      [Color(0xFF1B5E20), Color(0xFF43A047)],
    ),
    _NavSpec(
      Icons.sensors_rounded,
      Icons.sensors,
      'Live',
      true,
      [Color(0xFFB71C1C), Color(0xFFE53935)],
    ),
    _NavSpec(
      Icons.newspaper_rounded,
      Icons.newspaper,
      'News',
      false,
      [Color(0xFF4A148C), Color(0xFF8E24AA)],
    ),
    _NavSpec(
      Icons.grid_view_rounded,
      Icons.grid_view,
      'Browse',
      false,
      [Color(0xFFE65100), Color(0xFFFF6F00)],
    ),
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
  final List<Color> accentGradient;

  const _NavSpec(
    this.icon,
    this.activeIcon,
    this.label,
    this.liveHint,
    this.accentGradient,
  );
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

  Color get _activeColor => spec.accentGradient.last;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: _activeColor.withValues(alpha: 0.15),
        highlightColor: _activeColor.withValues(alpha: 0.08),
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
                        colors: spec.accentGradient
                            .map((c) => c.withValues(alpha: isDark ? 0.55 : 0.35))
                            .toList(),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: active ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: active
                    ? Border.all(
                        color: _activeColor.withValues(alpha: 0.5),
                        width: 1,
                      )
                    : null,
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: _activeColor.withValues(alpha: 0.35),
                          blurRadius: 12,
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
                    color: active ? _activeColor : context.txt3,
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
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.liveRed.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
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
                  color: active ? _activeColor : context.txt3,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
              ),
            ),
            SizedBox(
              height: 3,
              child: active
                  ? Container(
                      width: 18,
                      height: 2.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: spec.accentGradient),
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
