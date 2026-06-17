import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio_tv/provider/channel_catalog_provider.dart';
import 'package:lumio_tv/screens/category_channels_screen.dart';
import 'package:lumio_tv/screens/special_link/special_link_hub_screen.dart';
import 'package:lumio_tv/theme/app_theme.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;

/// Home tab category grid — gradient tiles, counts, staggered entrance.
class HomeCategoryGrid extends StatefulWidget {
  final ChannelCatalogProvider prov;
  final List<Map<String, String>> categories;
  final String? highlightCategory;
  final ValueChanged<String>? onCategoryTap;

  const HomeCategoryGrid({
    super.key,
    required this.prov,
    this.categories = const [],
    this.highlightCategory,
    this.onCategoryTap,
  });

  @override
  State<HomeCategoryGrid> createState() => _HomeCategoryGridState();
}

class _HomeCategoryGridState extends State<HomeCategoryGrid>
    with TickerProviderStateMixin {
  static const _cols = 3;
  static const _gap = 10.0;

  late final AnimationController _entrance;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  int _channelCount(String internalCat) => widget.prov
      .byCategory(internalCat)
      .where((ch) => ch.streamUrl.isNotEmpty)
      .length;

  void _openCategory(
    BuildContext context, {
    required String label,
    required String internal,
    required String iconEmoji,
  }) {
    HapticFeedback.lightImpact();
    widget.onCategoryTap?.call(internal);

    if (internal == ChannelCatalogProvider.specialLinkCategoryId) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const SpecialLinkHubScreen(),
        ),
      );
      return;
    }

    final list = widget.prov
        .byCategory(internal)
        .where((ch) => ch.streamUrl.isNotEmpty)
        .toList();
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No live channels in $label right now'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CategoryChannelsScreen(
          categoryName: internal,
          categoryIcon: iconEmoji,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories.isNotEmpty
        ? widget.categories
        : widget.prov.homeCategoryTiles;
    final itemCount = cats.length;
    final rowCount = (itemCount / _cols).ceil();

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final width = constraints.maxWidth;
        final cellW = ((width - _gap * (_cols - 1)) / _cols).floorToDouble();
        final cellH = (cellW * 1.14).floorToDouble();
        final gridH = cellH * rowCount + _gap * (rowCount - 1);

        Widget cellAt(int index) {
          if (index >= itemCount) return const SizedBox.shrink();

          final stagger = Interval(
            (index / itemCount) * 0.55,
            math.min(1.0, (index / itemCount) * 0.55 + 0.45),
            curve: Curves.easeOutCubic,
          );
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.14),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: _entrance, curve: stagger));
          final fade = CurvedAnimation(parent: _entrance, curve: stagger);

          final cat = cats[index];
          final label = cat['label']!;
          final internal = cat['cat']!;
          final selected = widget.highlightCategory == internal ||
              widget.highlightCategory == label;
          final isSpecial = internal == ChannelCatalogProvider.specialLinkCategoryId;
          final count = isSpecial ? 0 : _channelCount(internal);
          final tile = _CategoryTile(
            label: label,
            subtitle: isSpecial
                ? 'GITUN playlists'
                : (count > 0 ? '$count live' : 'Coming soon'),
            emoji: cat['icon'],
            visual: _CategoryVisual.forCategory(internal, context.isDark),
            channelCount: isSpecial ? null : (count > 0 ? count : null),
            selected: selected,
            pulse: _pulse,
            onTap: () => _openCategory(
              context,
              label: label,
              internal: internal,
              iconEmoji: cat['icon']!,
            ),
          );

          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: tile),
          );
        }

        Widget rowAt(int row) {
          return SizedBox(
            width: width,
            height: cellH,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_cols, (col) {
                return SizedBox(
                  width: cellW,
                  height: cellH,
                  child: cellAt(row * _cols + col),
                );
              }),
            ),
          );
        }

        return SizedBox(
          width: width,
          height: gridH,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < rowCount; r++) ...[
                if (r > 0) const SizedBox(height: _gap),
                rowAt(r),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CategoryVisual {
  final IconData icon;
  final List<Color> gradient;
  final Color glow;
  final Color iconFg;
  final Color badgeBg;

  const _CategoryVisual({
    required this.icon,
    required this.gradient,
    required this.glow,
    required this.iconFg,
    required this.badgeBg,
  });

  static _CategoryVisual forCategory(String cat, bool isDark) {
    switch (cat) {
      case 'Sports':
        return _CategoryVisual(
          icon: Icons.sports_soccer_rounded,
          gradient: const [
            Color(0xFF0D47A1),
            Color(0xFF1565C0),
            Color(0xFF1B5E20),
          ],
          glow: const Color(0xFF66BB6A),
          iconFg: Colors.white,
          badgeBg: const Color(0xFF2E7D32),
        );
      case 'Entertainment':
        return _CategoryVisual(
          icon: Icons.theater_comedy_rounded,
          gradient: const [
            Color(0xFF4A148C),
            Color(0xFF7B1FA2),
            Color(0xFFAD1457),
          ],
          glow: const Color(0xFFCE93D8),
          iconFg: Colors.white,
          badgeBg: const Color(0xFF8E24AA),
        );
      case 'Movies':
        return _CategoryVisual(
          icon: Icons.movie_rounded,
          gradient: const [
            Color(0xFFE65100),
            Color(0xFFFF6F00),
            Color(0xFFFFB300),
          ],
          glow: const Color(0xFFFFB74D),
          iconFg: Colors.white,
          badgeBg: const Color(0xFFEF6C00),
        );
      case 'KDrama':
        return _CategoryVisual(
          icon: Icons.live_tv_rounded,
          gradient: const [
            Color(0xFF880E4F),
            Color(0xFFC2185B),
            Color(0xFFEC407A),
          ],
          glow: const Color(0xFFF48FB1),
          iconFg: Colors.white,
          badgeBg: const Color(0xFFD81B60),
        );
      case 'Bangladesh':
        return _CategoryVisual(
          icon: Icons.language_rounded,
          gradient: const [
            Color(0xFF004D40),
            Color(0xFF00695C),
            Color(0xFF2E7D32),
          ],
          glow: const Color(0xFF4DB6AC),
          iconFg: Colors.white,
          badgeBg: const Color(0xFF00897B),
        );
      case 'News':
        return _CategoryVisual(
          icon: Icons.newspaper_rounded,
          gradient: const [
            Color(0xFF0D47A1),
            Color(0xFF1976D2),
            Color(0xFF0277BD),
          ],
          glow: const Color(0xFF64B5F6),
          iconFg: Colors.white,
          badgeBg: const Color(0xFF1565C0),
        );
      case 'Kids':
        return _CategoryVisual(
          icon: Icons.child_care_rounded,
          gradient: const [
            Color(0xFF1B5E20),
            Color(0xFF388E3C),
            Color(0xFF689F38),
          ],
          glow: const Color(0xFF81C784),
          iconFg: Colors.white,
          badgeBg: const Color(0xFF43A047),
        );
      case 'Hindi':
        return _CategoryVisual(
          icon: Icons.movie_filter_rounded,
          gradient: const [
            Color(0xFFE65100),
            Color(0xFFFF8F00),
            Color(0xFFFFB300),
          ],
          glow: const Color(0xFFFFCC80),
          iconFg: Colors.white,
          badgeBg: const Color(0xFFEF6C00),
        );
      case 'English':
        return _CategoryVisual(
          icon: Icons.public_rounded,
          gradient: const [
            Color(0xFF0D47A1),
            Color(0xFF283593),
            Color(0xFF4527A0),
          ],
          glow: const Color(0xFF7986CB),
          iconFg: Colors.white,
          badgeBg: const Color(0xFF3949AB),
        );
      case 'Pakistan':
        return _CategoryVisual(
          icon: Icons.flag_rounded,
          gradient: const [
            Color(0xFF1B5E20),
            Color(0xFF2E7D32),
            Color(0xFF388E3C),
          ],
          glow: const Color(0xFF66BB6A),
          iconFg: Colors.white,
          badgeBg: const Color(0xFF2E7D32),
        );
      case 'Live TV':
        return _CategoryVisual(
          icon: Icons.sensors_rounded,
          gradient: const [
            Color(0xFF37474F),
            Color(0xFF455A64),
            Color(0xFF546E7A),
          ],
          glow: const Color(0xFF90A4AE),
          iconFg: Colors.white,
          badgeBg: const Color(0xFF607D8B),
        );
      case '__special_link__':
        return _CategoryVisual(
          icon: Icons.link_rounded,
          gradient: const [
            Color(0xFF311B92),
            Color(0xFF4527A0),
            Color(0xFF00695C),
          ],
          glow: const Color(0xFF80CBC4),
          iconFg: Colors.white,
          badgeBg: const Color(0xFF5E35B1),
        );
      default:
        return more(isDark);
    }
  }

  static _CategoryVisual more(bool isDark) => _CategoryVisual(
        icon: Icons.grid_view_rounded,
        gradient: isDark
            ? const [
                Color(0xFF1A237E),
                Color(0xFF283593),
                Color(0xFF37474F),
              ]
            : const [
                Color(0xFF5C6BC0),
                Color(0xFF7986CB),
                Color(0xFF455A64),
              ],
        glow: tokens.AppTokens.accent,
        iconFg: Colors.white,
        badgeBg: tokens.AppTokens.accent,
      );
}

class _CategoryTile extends StatefulWidget {
  final String label;
  final String subtitle;
  final String? emoji;
  final _CategoryVisual visual;
  final int? channelCount;
  final bool selected;
  final Animation<double> pulse;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.subtitle,
    this.emoji,
    required this.visual,
    required this.channelCount,
    required this.selected,
    required this.pulse,
    required this.onTap,
  });

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final hasLive = (widget.channelCount ?? 0) > 0;
    final selected = widget.selected;

    return AnimatedBuilder(
      animation: widget.pulse,
      builder: (context, child) {
        final breathe = hasLive ? 1.0 + widget.pulse.value * 0.035 : 1.0;
        return Transform.scale(
          scale: (_pressed ? 0.96 : 1.0) * breathe,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.visual.gradient,
            ),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.18),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.visual.glow.withValues(
                  alpha: selected ? 0.45 : (hasLive ? 0.32 : 0.2),
                ),
                blurRadius: selected ? 18 : 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Stack(
              children: [
                Positioned(
                  left: -20,
                  top: -24,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  right: -18,
                  bottom: -22,
                  child: Icon(
                    widget.visual.icon,
                    size: 76,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                if (widget.emoji != null && widget.emoji!.isNotEmpty)
                  Positioned(
                    right: 6,
                    bottom: 4,
                    child: Opacity(
                      opacity: 0.35,
                      child: Text(
                        widget.emoji!,
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                  ),
                if (hasLive)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _LiveDot(pulse: widget.pulse),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: widget.emoji != null && widget.emoji!.isNotEmpty
                            ? Text(
                                widget.emoji!,
                                style: const TextStyle(fontSize: 20),
                              )
                            : Icon(
                                widget.visual.icon,
                                size: 20,
                                color: widget.visual.iconFg,
                              ),
                      ),
                      const Spacer(),
                      Text(
                        widget.label,
                        style: GF.head(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: GF.body(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  final Animation<double> pulse;

  const _LiveDot({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: tokens.AppTokens.liveRed.withValues(
              alpha: 0.85 + pulse.value * 0.15,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: tokens.AppTokens.liveRed
                    .withValues(alpha: 0.4 * pulse.value),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'LIVE',
                style: GF.body(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Section title row for home blocks.
class HomeSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const HomeSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GF.head(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.txt,
                    letterSpacing: 0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: GF.body(
                      fontSize: 11,
                      color: context.txt3,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
