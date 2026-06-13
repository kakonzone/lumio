// lib/utils/page_transitions.dart
import 'package:flutter/material.dart';
import 'package:lumio_tv/theme/tokens/motion.dart' as tokens;

/// Custom page transition utilities for consistent app navigation.
///
/// Features:
/// - Fade + slight slide (16px upward) for standard navigation
/// - Shared element transitions via Hero widgets
/// - Respects reduce motion setting
/// - Replaces MaterialPageRoute for consistent feel
class PageTransitions {
  PageTransitions._();

  /// Standard page transition: fade + slight slide (16px upward)
  static Route<T> fadeSlideUp<T>({required WidgetBuilder builder}) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) {
        return builder(context);
      },
      transitionDuration: tokens.MotionTokens.pageTransition,
      reverseTransitionDuration: tokens.MotionTokens.pageTransition,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return _FadeSlideUpTransition(
          animation: animation,
          child: child,
        );
      },
    );
  }

  /// Fade-only transition (for dialogs, overlays)
  static Route<T> fade<T>({required WidgetBuilder builder}) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) {
        return builder(context);
      },
      transitionDuration: tokens.MotionTokens.modal,
      reverseTransitionDuration: tokens.MotionTokens.modal,
      opaque: false,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  /// Bottom sheet transition (spring open from bottom)
  static Route<T> bottomSheet<T>({required WidgetBuilder builder}) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) {
        return builder(context);
      },
      transitionDuration: tokens.MotionTokens.bottomSheet,
      reverseTransitionDuration: tokens.MotionTokens.bottomSheet,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: tokens.MotionTokens.curveSpring,
          )),
          child: child,
        );
      },
    );
  }

  /// Instant transition (no animation, for reduce motion)
  static Route<T> instant<T>({required WidgetBuilder builder}) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) {
        return builder(context);
      },
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
    );
  }

  /// Check if reduce motion is enabled and return appropriate transition
  static Route<T> adaptive<T>({
    required WidgetBuilder builder,
    Route<T>? customTransition,
  }) {
    // Need BuildContext to check reduce motion, so this is a helper
    // The actual reduce motion check should be done at the call site
    return customTransition ?? fadeSlideUp(builder: builder);
  }
}

/// Internal fade + slide up transition widget
class _FadeSlideUpTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _FadeSlideUpTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = tokens.MotionTokens.reduceMotion(context);

    if (reduceMotion) {
      return child;
    }

    return SlideTransition(
      position: Tween<Offset>(
        begin:
            const Offset(0, 0.04), // 16px upward (roughly 4% of screen height)
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: tokens.MotionTokens.pageCurve,
      )),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}

/// Extension to easily use custom transitions with Navigator
extension CustomNavigatorExtension on Navigator {
  /// Push with fade + slide up transition
  Future<T?> pushFadeSlideUp<T>(Route<T> route) {
    return push(route);
  }

  /// Push with fade-only transition
  Future<T?> pushFade<T>(Route<T> route) {
    return push(route);
  }
}

/// Shared hero tag generator for consistent hero animations
class HeroTags {
  HeroTags._();

  /// Generate a unique hero tag for channel artwork
  static String channelArtwork(String channelId) {
    return 'channel_artwork_$channelId';
  }

  /// Generate a unique hero tag for movie poster
  static String moviePoster(String movieId) {
    return 'movie_poster_$movieId';
  }

  /// Generate a unique hero tag for series thumbnail
  static String seriesThumbnail(String seriesId) {
    return 'series_thumbnail_$seriesId';
  }

  /// Generate a unique hero tag for category icon
  static String categoryIcon(String categoryId) {
    return 'category_icon_$categoryId';
  }

  /// Generate a unique hero tag for user avatar
  static String userAvatar(String userId) {
    return 'user_avatar_$userId';
  }
}

/// Hero widget wrapper with consistent animation settings
class AppHero extends StatelessWidget {
  final String tag;
  final Widget child;
  final bool enabled;

  const AppHero({
    super.key,
    required this.tag,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    return Hero(
      tag: tag,
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
      flightShuttleBuilder:
          (flightContext, animation, direction, fromContext, toContext) {
        return DefaultTextStyle(
          style: DefaultTextStyle.of(toContext).style,
          child: toContext.widget,
        );
      },
    );
  }
}
