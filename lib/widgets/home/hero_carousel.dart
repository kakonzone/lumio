// lib/widgets/home/hero_carousel.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lumio_tv/l10n/strings.dart' as strings;
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/typography.dart' as tokens;
import 'package:lumio_tv/theme/tokens/motion.dart' as tokens;
import 'package:lumio_tv/utils/haptic_helpers.dart' as haptics;

/// Hero carousel widget with editorial layout for home screen.
/// 
/// Features:
/// - 60% viewport height
/// - Full-bleed background image with gradient overlay
/// - Display font heading (Instrument Serif)
/// - Auto-rotation every 8 seconds
/// - Swipeable with parallax effect
/// - "Watch Now" and "More Info" buttons
class HeroCarousel extends StatefulWidget {
  final List<HeroItem> items;
  final void Function(HeroItem item) onWatchNow;
  final void Function(HeroItem item) onMoreInfo;

  const HeroCarousel({
    super.key,
    required this.items,
    required this.onWatchNow,
    required this.onMoreInfo,
  });

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _rotationController;
  int _currentIndex = 0;
  Timer? _rotationTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    
    if (widget.items.isNotEmpty) {
      _startAutoRotation();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _rotationController.dispose();
    _rotationTimer?.cancel();
    super.dispose();
  }

  void _startAutoRotation() {
    _rotationTimer?.cancel();
    _rotationController.reset();
    
    _rotationController.forward().then((_) {
      if (mounted && widget.items.length > 1) {
        _rotateToNext();
      }
    });
  }

  void _rotateToNext() {
    if (!mounted) return;
    
    final nextIndex = (_currentIndex + 1) % widget.items.length;
    _pageController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _startAutoRotation();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          return _HeroSlide(
            item: widget.items[index],
            onWatchNow: () {
              Haptics.buttonPress();
              widget.onWatchNow(widget.items[index]);
            },
            onMoreInfo: () {
              Haptics.buttonPress();
              widget.onMoreInfo(widget.items[index]);
            },
          );
        },
      ),
    );
  }
}

class _HeroSlide extends StatelessWidget {
  final HeroItem item;
  final VoidCallback onWatchNow;
  final VoidCallback onMoreInfo;

  const _HeroSlide({
    required this.item,
    required this.onWatchNow,
    required this.onMoreInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image
        CachedNetworkImage(
          imageUrl: item.imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: tokens.AppTokens.surface2,
          ),
          errorWidget: (context, url, error) => Container(
            color: tokens.AppTokens.surface2,
          ),
        ),
        
        // Gradient overlay (bottom 40% fades to background black)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                  tokens.AppTokens.background,
                ],
                stops: const [0.0, 0.4, 0.6, 0.8, 1.0],
              ),
            ),
          ),
        ),
        
        // Content (asymmetric layout, anchored bottom-left)
        Positioned(
          left: tokens.SpacingTokens.s24,
          right: tokens.SpacingTokens.s24,
          bottom: tokens.SpacingTokens.s24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // LIVE badge (if applicable)
              if (item.isLive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: tokens.SpacingTokens.s8,
                    vertical: tokens.SpacingTokens.s4,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.AppTokens.liveRed,
                    borderRadius: tokens.RadiusTokens.circularSm,
                  ),
                  child: Text(
                    strings.Strings.liveIndicator,
                    style: tokens.TypographyTokens.captionPrimary,
                  ),
                ),
              
              if (item.isLive)
                const SizedBox(height: tokens.SpacingTokens.s12),
              
              // Display font heading
              Text(
                item.title,
                style: tokens.TypographyTokens.displayPrimary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: tokens.SpacingTokens.s8),
              
              // Body text (current program)
              Text(
                item.subtitle,
                style: tokens.TypographyTokens.bodySecondary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: tokens.SpacingTokens.s24),
              
              // Button row
              Row(
                children: [
                  // Watch Now button (primary, accent)
                  ElevatedButton(
                    onPressed: onWatchNow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.AppTokens.accent,
                      foregroundColor: tokens.AppTokens.textPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: tokens.SpacingTokens.s24,
                        vertical: tokens.SpacingTokens.s12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: tokens.RadiusTokens.circularMd,
                      ),
                    ),
                    child: Text(strings.Strings.continueText),
                  ),
                  
                  const SizedBox(width: tokens.SpacingTokens.s12),
                  
                  // More Info button (ghost)
                  OutlinedButton(
                    onPressed: onMoreInfo,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.AppTokens.textPrimary,
                      side: BorderSide(
                        color: tokens.AppTokens.border,
                        width: 1,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: tokens.SpacingTokens.s24,
                        vertical: tokens.SpacingTokens.s12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: tokens.RadiusTokens.circularMd,
                      ),
                    ),
                    child: const Text('More info'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Hero item data model
class HeroItem {
  final String title;
  final String subtitle;
  final String imageUrl;
  final bool isLive;
  final String? channelId;
  final String? programId;

  const HeroItem({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.isLive = false,
    this.channelId,
    this.programId,
  });
}
