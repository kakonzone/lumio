// lib/widgets/common/pressable.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio_tv/theme/tokens/motion.dart' as tokens;

/// A pressable widget that wraps any child with press animations and haptic feedback.
/// 
/// Features:
/// - Scale to 0.96 and opacity to 0.8 on tap down (100ms)
/// - Spring back animation on tap up (200ms with curveSpring)
/// - HapticFeedback.lightImpact() on tap down
/// - Respects reduce motion setting
/// - Accessibility support with semantic labels
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final BorderRadius? borderRadius;
  final Color? splashColor;
  final Color? highlightColor;
  final String? semanticLabel;
  final String? semanticHint;
  final bool isButton;
  final bool isLink;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.borderRadius,
    this.splashColor,
    this.highlightColor,
    this.semanticLabel,
    this.semanticHint,
    this.isButton = true,
    this.isLink = false,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: tokens.MotionTokens.pressDown,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: tokens.MotionTokens.pressCurve,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: tokens.MotionTokens.pressCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePressDown(TapDownDetails details) {
    if (!widget.enabled) return;

    // Check for reduce motion
    if (!tokens.MotionTokens.reduceMotion(context)) {
      _controller.duration = tokens.MotionTokens.pressDown;
      _controller.forward();
    }

    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  void _handlePressUp(TapUpDetails details) {
    if (!widget.enabled) return;

    // Check for reduce motion
    if (!tokens.MotionTokens.reduceMotion(context)) {
      _controller.duration = tokens.MotionTokens.pressUp;
      _controller.reverse();
    }
  }

  void _handlePressCancel() {
    if (!widget.enabled) return;

    if (!tokens.MotionTokens.reduceMotion(context)) {
      _controller.duration = tokens.MotionTokens.pressUp;
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return ExcludeSemantics(
        excluding: true,
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = tokens.MotionTokens.reduceMotion(context)
            ? 1.0
            : _scaleAnimation.value;
        final opacity = tokens.MotionTokens.reduceMotion(context)
            ? 1.0
            : _opacityAnimation.value;

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Semantics(
              button: widget.isButton,
              link: widget.isLink,
              label: widget.semanticLabel,
              hint: widget.semanticHint,
              enabled: widget.onTap != null,
              onTap: widget.onTap,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  onLongPress: widget.onLongPress,
                  onTapDown: _handlePressDown,
                  onTapUp: _handlePressUp,
                  onTapCancel: _handlePressCancel,
                  borderRadius: widget.borderRadius,
                  splashColor: widget.splashColor,
                  highlightColor: widget.highlightColor,
                  child: widget.child,
                ),
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
