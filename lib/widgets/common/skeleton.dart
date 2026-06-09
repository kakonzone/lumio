// lib/widgets/common/skeleton.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/motion.dart' as tokens;

/// A skeleton loading widget with shimmer effect.
/// 
/// Replaces CircularProgressIndicator for content areas.
/// 
/// Spec: Surface2 base, Surface3 highlight, 1200ms cycle, easeInOut curve.
class Skeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  const Skeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = tokens.AppTokens.surface2;
    final highlightColor = tokens.AppTokens.surface3;
    final reduceMotion = tokens.MotionTokens.reduceMotion(context);

    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      child: reduceMotion
          ? null
          : _ShimmerEffect(
              baseColor: baseColor,
              highlightColor: highlightColor,
            ),
    );
  }
}

class _ShimmerEffect extends StatelessWidget {
  final Color baseColor;
  final Color highlightColor;

  const _ShimmerEffect({
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            highlightColor,
            baseColor,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
    ).animate(
      onPlay: (controller) => controller.repeat(),
    ).shimmer(
      duration: tokens.MotionTokens.shimmerCycle,
      curve: tokens.MotionTokens.shimmerCurve,
      color: highlightColor,
      angle: 45,
    );
  }
}

/// Pre-built skeleton shapes for common UI patterns
class SkeletonShapes {
  /// Avatar circle (typically 48x48)
  static Widget avatar({double size = 48}) {
    return Skeleton(
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
    );
  }

  /// Thumbnail rectangle (16:9 aspect ratio)
  static Widget thumbnail({double width = 200}) {
    return Skeleton(
      width: width,
      height: width * 9 / 16,
      borderRadius: BorderRadius.circular(8),
    );
  }

  /// Line of text (typically for body text)
  static Widget textLine({double? width, double height = 16}) {
    return Skeleton(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(4),
    );
  }

  /// Title line (typically larger and bolder)
  static Widget title({double? width, double height = 24}) {
    return Skeleton(
      width: width ?? double.infinity,
      height: height,
      borderRadius: BorderRadius.circular(4),
    );
  }

  /// Button skeleton
  static Widget button({double? width, double height = 48}) {
    return Skeleton(
      width: width ?? 120,
      height: height,
      borderRadius: BorderRadius.circular(8),
    );
  }

  /// Card skeleton (full width with padding)
  static Widget card({
    double? width,
    double height = 100,
    EdgeInsetsGeometry? padding,
  }) {
    return Skeleton(
      width: width,
      height: height,
      padding: padding,
      borderRadius: BorderRadius.circular(12),
    );
  }

  /// List tile skeleton (avatar + text lines)
  static Widget listTile({double? width}) {
    return Row(
      children: [
        avatar(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              title(width: width ?? 150),
              const SizedBox(height: 8),
              textLine(width: width ?? 200),
            ],
          ),
        ),
      ],
    );
  }
}

/// Skeleton box that can contain optional subtitle text
class SkeletonBox extends StatelessWidget {
  final Widget child;
  final String? subtitle;
  final EdgeInsetsGeometry? padding;

  const SkeletonBox({
    super.key,
    required this.child,
    this.subtitle,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                color: tokens.AppTokens.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
