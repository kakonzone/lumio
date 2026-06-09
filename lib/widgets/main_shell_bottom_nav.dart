import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:lumio_tv/theme/app_theme.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/radius.dart' as tokens;
import 'package:lumio_tv/theme/tokens/motion.dart' as tokens;

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
      PhosphorIcons.house,
      'Home',
      false,
    ),
    _NavSpec(
      PhosphorIcons.soccer_ball,
      'Sports',
      true,
    ),
    _NavSpec(
      PhosphorIcons.television,
      'Live',
      true,
    ),
    _NavSpec(
      PhosphorIcons.newspaper,
      'News',
      false,
    ),
    _NavSpec(
      PhosphorIcons.grid_four,
      'Browse',
      false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.AppTokens.surface1,
        border: Border(top: BorderSide(color: tokens.AppTokens.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
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
                  showLiveBadge: showBadge,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTap(i);
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavSpec {
  final IconData icon;
  final String label;
  final bool liveHint;

  const _NavSpec(
    this.icon,
    this.label,
    this.liveHint,
  );
}

class _NavTile extends StatelessWidget {
  final _NavSpec spec;
  final bool active;
  final bool showLiveBadge;
  final VoidCallback onTap;

  const _NavTile({
    required this.spec,
    required this.active,
    required this.showLiveBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: tokens.RadiusTokens.circularLg,
        splashColor: tokens.AppTokens.accent.withValues(alpha: 0.15),
        highlightColor: tokens.AppTokens.accent.withValues(alpha: 0.08),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated indicator dot (4px above icon)
            SizedBox(
              height: tokens.SpacingTokens.s4,
              child: AnimatedSwitcher(
                duration: tokens.MotionTokens.navIndicator,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.5),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: tokens.MotionTokens.navCurve,
                      )),
                      child: child,
                    ),
                  );
                },
                child: active
                    ? Container(
                        key: const ValueKey('indicator'),
                        width: tokens.SpacingTokens.s4,
                        height: tokens.SpacingTokens.s4,
                        decoration: const BoxDecoration(
                          color: tokens.AppTokens.accent,
                          shape: BoxShape.circle,
                        ),
                      )
                    : const SizedBox(
                        key: ValueKey('empty'),
                        width: tokens.SpacingTokens.s4,
                        height: tokens.SpacingTokens.s4,
                      ),
              ),
            ),
            SizedBox(height: tokens.SpacingTokens.s4),
            // Icon with live badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: tokens.MotionTokens.navIndicator,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: Icon(
                    spec.icon,
                    size: 24,
                    color: active ? tokens.AppTokens.accent : tokens.AppTokens.textTertiary,
                    key: ValueKey('${spec.label}_${active}'),
                  ),
                ),
                if (showLiveBadge)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: tokens.AppTokens.liveRed,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.cardSurface,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tokens.AppTokens.liveRed.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: tokens.SpacingTokens.s4),
            // Label (11px)
            AnimatedSwitcher(
              duration: tokens.MotionTokens.navIndicator,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              child: Text(
                spec.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? tokens.AppTokens.accent : tokens.AppTokens.textTertiary,
                  letterSpacing: 0,
                ),
                maxLines: 1,
                key: ValueKey('${spec.label}_text_${active}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
