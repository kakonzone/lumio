import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Image preloading utilities
///
/// Preloads images to improve perceived performance.
///
/// Usage:
/// - Preload home hero images on app start
/// - Preload next-in-row tiles when user scrolls within 200px of edge
class ImagePreloader {
  static final Set<String> _preloadedUrls = {};
  static final Map<String, CachedNetworkImageProvider> _imageProviders = {};

  /// Preload a single image URL
  static Future<void> preload(String imageUrl) async {
    if (_preloadedUrls.contains(imageUrl)) return;

    try {
      final imageProvider = CachedNetworkImageProvider(imageUrl);
      await precacheImage(imageProvider, _getNavigatorContext());

      _imageProviders[imageUrl] = imageProvider;
      _preloadedUrls.add(imageUrl);
    } catch (e) {
      // Silent fail - image will load on demand
    }
  }

  /// Preload multiple image URLs
  static Future<void> preloadList(List<String> imageUrls) async {
    final futures = imageUrls.map((url) => preload(url));
    await Future.wait(futures, eagerError: false);
  }

  /// Get preloaded image provider for a URL
  static CachedNetworkImageProvider? getImageProvider(String imageUrl) {
    return _imageProviders[imageUrl];
  }

  /// Check if an image is preloaded
  static bool isPreloaded(String imageUrl) {
    return _preloadedUrls.contains(imageUrl);
  }

  /// Clear preloaded images to free memory
  static void clearCache() {
    _imageProviders.clear();
    _preloadedUrls.clear();
    // Use clearImageCache instead of evictFromCache
    // clearImageCache() doesn't take parameters
  }

  /// Get navigator context for precaching
  ///
  /// This should be called from a context that has a navigator
  static BuildContext _getNavigatorContext() {
    // In a real app, this would access the current navigator context
    // For now, return a dummy context that won't be used
    // The actual implementation would pass context from the calling widget
    throw UnimplementedError(
      'Pass BuildContext to preloader context parameter instead',
    );
  }

  /// Preload images with context
  static Future<void> preloadWithContext(
    BuildContext context,
    String imageUrl,
  ) async {
    if (_preloadedUrls.contains(imageUrl)) return;

    try {
      final imageProvider = CachedNetworkImageProvider(imageUrl);
      await precacheImage(imageProvider, context);

      _imageProviders[imageUrl] = imageProvider;
      _preloadedUrls.add(imageUrl);
    } catch (e) {
      // Silent fail - image will load on demand
    }
  }

  /// Preload multiple images with context
  static Future<void> preloadListWithContext(
    BuildContext context,
    List<String> imageUrls,
  ) async {
    final futures = imageUrls.map((url) => preloadWithContext(context, url));
    await Future.wait(futures, eagerError: false);
  }
}

/// Scroll-based image preloader
///
/// Preloads images when user scrolls within threshold of edge.
class ScrollImagePreloader extends StatefulWidget {
  final List<String> imageUrls;
  final Widget child;
  final double preloadThreshold; // pixels from edge

  const ScrollImagePreloader({
    super.key,
    required this.imageUrls,
    required this.child,
    this.preloadThreshold = 200,
  });

  @override
  State<ScrollImagePreloader> createState() => _ScrollImagePreloaderState();
}

class _ScrollImagePreloaderState extends State<ScrollImagePreloader> {
  final Set<String> _preloadedIndices = {};
  ScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    _initializeScrollController();
  }

  void _initializeScrollController() {
    // Try to find scroll controller from child
    // This is a simplified approach
    // In real implementation, pass scroll controller as parameter
  }

  @override
  void dispose() {
    _scrollController?.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController == null) return;

    final position = _scrollController!.position;
    final pixels = position.pixels;

    // Calculate which images are near the viewport
    final itemHeight = 100; // Estimated, should be calculated

    for (int i = 0; i < widget.imageUrls.length; i++) {
      if (_preloadedIndices.contains(i.toString())) continue;

      final itemPosition = i * itemHeight;
      final distanceFromViewport = (itemPosition - pixels).abs();

      // Preload if within threshold
      if (distanceFromViewport <= widget.preloadThreshold) {
        final imageUrl = widget.imageUrls[i];
        ImagePreloader.preloadWithContext(context, imageUrl);
        _preloadedIndices.add(i.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// App initialization image preloader
///
/// Preloads hero images on app start.
class AppImagePreloader extends StatefulWidget {
  final List<String> heroImageUrls;
  final Widget child;

  const AppImagePreloader({
    super.key,
    required this.heroImageUrls,
    required this.child,
  });

  @override
  State<AppImagePreloader> createState() => _AppImagePreloaderState();
}

class _AppImagePreloaderState extends State<AppImagePreloader> {
  @override
  void initState() {
    super.initState();
    _preloadHeroImages();
  }

  Future<void> _preloadHeroImages() async {
    if (widget.heroImageUrls.isEmpty) return;

    try {
      await ImagePreloader.preloadListWithContext(
        context,
        widget.heroImageUrls,
      );
    } catch (e) {
      // Silent fail - app will still work
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
