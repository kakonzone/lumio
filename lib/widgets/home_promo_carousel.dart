import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lumio_tv/screens/category_channels_screen.dart';
import 'package:lumio_tv/theme/app_theme.dart';
import 'package:lumio_tv/utils/session_debug_log.dart';

enum _PromoTapAction { sports, liveEvents, entertainment }

/// Full-width promo slider (Home scroll — Browse এর উপরে), auto-scroll + page dots.
class HomePromoCarousel extends StatefulWidget {
  /// Home tab-এর "Live" sub-tab (index 1) এ যেতে চাইলে।
  final VoidCallback? onLiveTabTap;

  /// When false, auto-scroll pauses (saves CPU while on Live/Today/Soon).
  final bool active;

  const HomePromoCarousel({
    super.key,
    this.onLiveTabTap,
    this.active = true,
  });

  @override
  State<HomePromoCarousel> createState() => _HomePromoCarouselState();
}

class _HomePromoCarouselState extends State<HomePromoCarousel> {
  static const _autoInterval = Duration(seconds: 5);

  final _pageCtrl = PageController();
  Timer? _autoTimer;
  int _page = 0;

  static final _slides = <_PromoSlide>[
    const _PromoSlide(
      assetPath: 'assets/images/fifa_wc26_banner_1.webp',
      action: _PromoTapAction.liveEvents,
    ),
    const _PromoSlide(
      assetPath: 'assets/images/fifa_wc26_banner_2.webp',
      action: _PromoTapAction.liveEvents,
    ),
    const _PromoSlide(
      title: 'Live Sports',
      subtitle: 'Cricket, football, IPL, BPL & more',
      emoji: '⚽',
      gradient: [Color(0xFF1A237E), Color(0xFF3949AB), Color(0xFF5C6BC0)],
      action: _PromoTapAction.sports,
    ),
    const _PromoSlide(
      title: 'Live Events',
      subtitle: 'Scores & channels for today\'s matches',
      emoji: '🏏',
      gradient: [Color(0xFF004D40), Color(0xFF00695C), Color(0xFF00897B)],
      action: _PromoTapAction.liveEvents,
    ),
    const _PromoSlide(
      title: 'Browse Channels',
      subtitle: 'Sports, movies, news & entertainment',
      emoji: '📺',
      gradient: [Color(0xFF4A148C), Color(0xFF6A1B9A), Color(0xFF8E24AA)],
      action: _PromoTapAction.entertainment,
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.active) _startAutoScroll();
  }

  @override
  void didUpdateWidget(HomePromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _startAutoScroll();
    } else if (!widget.active && oldWidget.active) {
      _autoTimer?.cancel();
    }
  }

  void _startAutoScroll() {
    if (!widget.active) return;
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(_autoInterval, (_) {
      if (!mounted || !_pageCtrl.hasClients) return;
      final next = (_page + 1) % _slides.length;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onSlideTap(_PromoSlide slide) {
    switch (slide.action) {
      case _PromoTapAction.sports:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const CategoryChannelsScreen(
              categoryName: 'Sports',
              categoryIcon: '⚽',
            ),
          ),
        );
        return;
      case _PromoTapAction.liveEvents:
        // #region agent log
        sessionDebugLog(
          location: 'home_promo_carousel.dart:_onSlideTap',
          message: 'Promo liveEvents tap',
          hypothesisId: 'H4-gesture-block',
          data: {'hasCallback': widget.onLiveTabTap != null},
        );
        // #endregion
        widget.onLiveTabTap?.call();
        return;
      case _PromoTapAction.entertainment:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const CategoryChannelsScreen(
              categoryName: 'Entertainment',
              categoryIcon: '🎭',
            ),
          ),
        );
        return;
    }
  }

  Widget _buildSlideContent(_PromoSlide slide) {
    if (slide.assetPath != null) {
      return Image.asset(
        slide.assetPath!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _GradientSlideBody(slide: slide),
      );
    }
    return _GradientSlideBody(slide: slide);
  }

  @override
  Widget build(BuildContext context) {
    const aspect = 2.35;
    const hPad = 16.0;
    const bottomGap = 10.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(hPad, 0, hPad, bottomGap),
      child: AspectRatio(
        aspectRatio: aspect,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageCtrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (ctx, i) {
                  final slide = _slides[i];
                  return GestureDetector(
                    onTap: () => _onSlideTap(slide),
                    child: _buildSlideContent(slide),
                  );
                },
              ),
              Positioned(
                right: 14,
                bottom: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_slides.length, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.only(left: 5),
                      width: active ? 18 : 6,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: active ? 0.95 : 0.45),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientSlideBody extends StatelessWidget {
  final _PromoSlide slide;

  const _GradientSlideBody({required this.slide});

  @override
  Widget build(BuildContext context) {
    final gradient = slide.gradient;
    if (gradient == null || gradient.isEmpty) {
      return ColoredBox(color: context.bg2);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: Stack(
        children: [
          if (slide.emoji != null)
            Positioned(
              right: -12,
              bottom: -20,
              child: Opacity(
                opacity: 0.22,
                child: Text(
                  slide.emoji!,
                  style: const TextStyle(fontSize: 120),
                ),
              ),
            ),
          if (slide.title != null)
            Positioned(
              left: 18,
              right: 18,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (slide.emoji != null)
                    Text(slide.emoji!, style: const TextStyle(fontSize: 28)),
                  if (slide.emoji != null) const SizedBox(height: 8),
                  Text(
                    slide.title!,
                    style: GF.head(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (slide.subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      slide.subtitle!,
                      style: GF.body(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PromoSlide {
  final String? assetPath;
  final String? title;
  final String? subtitle;
  final String? emoji;
  final List<Color>? gradient;
  final _PromoTapAction action;

  const _PromoSlide({
    this.assetPath,
    this.title,
    this.subtitle,
    this.emoji,
    this.gradient,
    required this.action,
  });
}
