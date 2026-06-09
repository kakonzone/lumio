// lib/widgets/common/cached_image.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/radius.dart' as tokens;
import 'package:lumio_tv/widgets/common/skeleton.dart';

/// Cached image widget with fade-in transitions and skeleton loading
/// 
/// Features:
/// - Cached network images with memory cache
/// - Fade-in transition (300ms) on load
/// - Skeleton placeholder while loading
/// - Error fallback with icon
/// - Configurable placeholder and error widgets
class CachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;
  final bool showSkeleton;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.showSkeleton = true,
  });

  @override
  Widget build(BuildContext context) {
    final defaultPlaceholder = showSkeleton
        ? Skeleton(
            width: width,
            height: height,
            borderRadius: borderRadius,
          )
        : Container(
            width: width,
            height: height,
            color: tokens.AppTokens.surface2,
          );

    final defaultError = errorWidget ??
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: tokens.AppTokens.surface2,
            borderRadius: borderRadius ?? BorderRadius.circular(tokens.RadiusTokens.sm),
          ),
          child: Icon(
            Icons.broken_image,
            color: tokens.AppTokens.textTertiary,
          ),
        );

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit ?? BoxFit.cover,
        placeholder: (context, url) => defaultPlaceholder,
        errorWidget: (context, url, error) => defaultError,
        fadeInDuration: fadeInDuration,
        memCacheWidth: width != null ? (width * 2).toInt() : null,
        memCacheHeight: height != null ? (height * 2).toInt() : null,
        maxWidthDiskCache: 1000,
        maxHeightDiskCache: 1000,
      ),
    );
  }
}

/// Avatar image with automatic circle clipping
class CachedAvatar extends StatelessWidget {
  final String imageUrl;
  final double size;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedAvatar({
    super.key,
    required this.imageUrl,
    this.size = 48,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: CachedImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(size / 2),
        placeholder: placeholder,
        errorWidget: errorWidget,
      ),
    );
  }
}

/// Thumbnail image (16:9 aspect ratio)
class CachedThumbnail extends StatelessWidget {
  final String imageUrl;
  final double width;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedThumbnail({
    super.key,
    required this.imageUrl,
    required this.width,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final height = width * 9 / 16;

    return CachedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(8),
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}

/// Logo image with container fallback
class CachedLogo extends StatelessWidget {
  final String imageUrl;
  final String? name;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const CachedLogo({
    super.key,
    required this.imageUrl,
    this.name,
    this.width,
    this.height,
    this.fit,
  });

  @override
  Widget build(BuildContext context) {
    return CachedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: BorderRadius.circular(8),
      errorWidget: name != null && name!.isNotEmpty
          ? Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: tokens.AppTokens.surface3,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  name!.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: tokens.AppTokens.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: (width ?? 48) / 2,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}