// lib/widgets/common/page_transitions.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lumio_tv/theme/tokens/motion.dart' as tokens;

/// Page transition utilities for smooth screen changes
class PageTransitions {
  /// Standard fade-in page transition
  static Widget fadeInPage(
    Widget child, {
    Duration duration = tokens.MotionTokens.pageTransition,
    Curve curve = tokens.MotionTokens.curveDefault,
  }) {
    return child.animate().fadeIn(
      duration: duration,
      curve: curve,
    );
  }

  /// Slide-in from right page transition (iOS style)
  static Widget slideInFromRight(
    Widget child, {
    Duration duration = tokens.MotionTokens.pageTransition,
    Curve curve = tokens.MotionTokens.curveDefault,
  }) {
    return child.animate().slideX(
      begin: 0.1,
      end: 0,
      duration: duration,
      curve: curve,
    );
  }

  /// Slide-in from bottom page transition (Android style)
  static Widget slideInFromBottom(
    Widget child, {
    Duration duration = tokens.MotionTokens.pageTransition,
    Curve curve = tokens.MotionTokens.curveDefault,
  }) {
    return child.animate().slideY(
      begin: 0.1,
      end: 0,
      duration: duration,
      curve: curve,
    );
  }

  /// Scale-up page transition
  static Widget scaleInPage(
    Widget child, {
    Duration duration = tokens.MotionTokens.pageTransition,
    Curve curve = tokens.MotionTokens.curveSpring,
  }) {
    return child.animate().scale(
      begin: const Offset(0.95, 0.95),
      end: const Offset(1, 1),
      duration: duration,
      curve: curve,
    );
  }

  /// Fade with slide-up transition (staggered list items)
  static Widget staggeredItem(
    Widget child,
    int index, {
    Duration duration = tokens.MotionTokens.pageTransition,
    Duration delay = tokens.MotionTokens.pageTransition,
    Curve curve = tokens.MotionTokens.curveDefault,
  }) {
    final actualDelay = Duration(
      milliseconds: (delay.inMilliseconds * index)
          .clamp(0, 800)
          .toInt(),
    );

    return child.animate().fadeIn(
      duration: duration,
      curve: curve,
      delay: actualDelay,
    ).slideY(
      begin: 0.05,
      end: 0,
      duration: duration,
      curve: curve,
      delay: actualDelay,
    );
  }
}

/// Custom page route with animation
class AnimatedPageRoute extends PageRouteBuilder {
  final Widget child;
  final PageTransitionType transitionType;

  AnimatedPageRoute({
    required this.child,
    this.transitionType = PageTransitionType.fadeIn,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: tokens.MotionTokens.pageTransition,
          reverseTransitionDuration: tokens.MotionTokens.pageTransition,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            switch (transitionType) {
              case PageTransitionType.fadeIn:
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              case PageTransitionType.slideInRight:
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: tokens.MotionTokens.curveDefault,
                  )),
                  child: child,
                );
              case PageTransitionType.slideInBottom:
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: tokens.MotionTokens.curveDefault,
                  )),
                  child: child,
                );
            }
          },
        );
}

enum PageTransitionType {
  fadeIn,
  slideInRight,
  slideInBottom,
}
