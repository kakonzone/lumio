import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/shell_scope.dart';
import '../provider/favorites_provider.dart';
import '../provider/theme_provider.dart';
import '../screens/favorites_screen.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/colors.dart' as tokens;
import '../utils/responsive.dart';

/// Fixed top bar: drawer/back, logo, theme, favourites, notifications.
class ShellAppBar extends StatelessWidget {
  static const double _topBarHeight = 40;

  final String? title;
  final String? subtitle;
  final bool showBack;

  /// Home screen: LUMIO+TV brand dead-center on the bar.
  final bool centerLumioTvBrand;

  /// Match [Scaffold] body color so no dark strip appears under the bar.
  final bool blendWithScaffold;

  /// When [showBack], do not paint [subtitle] under the toolbar (put it in scroll).
  final bool hideSubtitleInBar;

  const ShellAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.showBack = false,
    this.centerLumioTvBrand = false,
    this.blendWithScaffold = false,
    this.hideSubtitleInBar = false,
  });

  void _openFavorites(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favCount = context.read<FavoritesProvider>().favoriteCount;

    final showSubtitleBelow =
        subtitle != null && showBack && !hideSubtitleInBar;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: blendWithScaffold ? context.bg : context.cardSurface,
        border: Border(bottom: BorderSide(color: context.brd)),
        boxShadow: [
          BoxShadow(
            color: context.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopRow(context, favCount),
              if (showSubtitleBelow) ...[
                const SizedBox(height: 6),
                OverflowSafeText(
                  subtitle!,
                  style: TextStyle(fontSize: 12, color: context.txt3),
                  maxLines: 1,
                ),
              ] else if (subtitle != null &&
                  !showBack &&
                  !centerLumioTvBrand) ...[
                const SizedBox(height: 12),
                if (title != null)
                  OverflowSafeText(
                    title!,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: context.txt,
                    ),
                    maxLines: 1,
                  ),
                const SizedBox(height: 4),
                OverflowSafeText(
                  subtitle!,
                  style: TextStyle(fontSize: 12, color: context.txt3),
                  maxLines: 2,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow(BuildContext context, int favCount) {
    final narrow = MediaQuery.sizeOf(context).width < 400;
    final sideSlot = Responsive.shellSideSlot(context);
    final left = showBack
        ? IconButton(
            icon: Icon(Icons.arrow_back, color: context.txt),
            onPressed: () => Navigator.maybePop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          )
        : GestureDetector(
            onTap: () => ShellScope.of(context).openDrawer(),
            child: SizedBox(
              width: 28,
              height: _topBarHeight,
              child: Icon(Icons.menu_rounded, color: context.txt, size: 24),
            ),
          );

    final right = _buildRightActions(context, favCount, compact: narrow);

    final Widget centerBrand;
    if (showBack && title != null && !centerLumioTvBrand) {
      centerBrand = OverflowSafeText(
        title!,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: context.txt,
        ),
        textAlign: TextAlign.center,
        scaleDown: true,
      );
    } else if (centerLumioTvBrand) {
      centerBrand = _lumioTvBrand(context);
    } else {
      centerBrand = _lumioBrand(context);
    }

    return SizedBox(
      height: _topBarHeight,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              SizedBox(
                width: sideSlot,
                height: _topBarHeight,
                child: Align(alignment: Alignment.centerLeft, child: left),
              ),
              const Spacer(),
              SizedBox(
                width: sideSlot,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _fitRightActions(right),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sideSlot + 4),
            child: Center(child: centerBrand),
          ),
        ],
      ),
    );
  }

  Widget _fitRightActions(Widget actions) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: actions,
    );
  }

  Widget _lumioBrand(BuildContext context) => OverflowSafeText(
        'LUMIO',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: context.txt,
          letterSpacing: 0.6,
        ),
        maxLines: 1,
        textAlign: TextAlign.center,
        scaleDown: true,
      );

  Widget _lumioTvBrand(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: RichText(
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
            children: [
              TextSpan(text: 'LUMIO', style: TextStyle(color: context.txt)),
              const TextSpan(
                text: 'TV',
                style: TextStyle(color: tokens.AppTokens.accent),
              ),
            ],
          ),
        ),
      );

  Widget _buildRightActions(
    BuildContext context,
    int favCount, {
    bool compact = false,
  }) {
    final themeProv = context.read<ThemeProvider>();
    final isDark = themeProv.isDark;
    final toggleTheme = themeProv.toggleTheme;
    final gap = compact ? 4.0 : 8.0;
    final toggleW = compact ? 44.0 : 52.0;
    final iconBox = compact ? 28.0 : 32.0;
    final knob = compact ? 18.0 : 22.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: toggleTheme,
          child: Container(
            width: toggleW,
            height: 26,
            decoration: BoxDecoration(
              color: context.bg3,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: context.brd),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  left: isDark ? 2 : (toggleW - knob - 2),
                  top: 2,
                  child: Container(
                    width: knob,
                    height: knob,
                    decoration: const BoxDecoration(
                      color: tokens.AppTokens.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        isDark ? '🌙' : '☀️',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: gap),
        GestureDetector(
          onTap: () => _openFavorites(context),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: iconBox,
                height: iconBox,
                decoration: BoxDecoration(
                  color: context.bg3,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.brd),
                ),
                child: Icon(
                  favCount > 0 ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: favCount > 0 ? tokens.AppTokens.accent : context.txt2,
                ),
              ),
              if (favCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: tokens.AppTokens.accent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      favCount > 9 ? '9+' : '$favCount',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(width: gap),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: iconBox,
              height: iconBox,
              decoration: BoxDecoration(
                color: context.bg3,
                shape: BoxShape.circle,
                border: Border.all(color: context.brd),
              ),
              child: Icon(
                Icons.notifications_none,
                size: 16,
                color: context.txt2,
              ),
            ),
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: tokens.AppTokens.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
