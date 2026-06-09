import 'package:flutter/material.dart';
import 'package:lumio_tv/widgets/common/skeleton_loaders.dart';

/// Shared performance utilities for Lumio app
/// 
/// This file consolidates performance optimization utilities
/// from individual feature implementations into a single location.
class PerformanceHelpers {
  /// Search debounce (300ms - matches Prompt 6)
  static const Duration searchDebounce = Duration(milliseconds: 300);
  
  /// Scroll preload throttle (100ms)
  static const Duration scrollPreloadThrottle = Duration(milliseconds: 100);
  
  /// Settings autosave debounce (500ms)
  static const Duration settingsAutosave = Duration(milliseconds: 500);
  
  /// Gesture throttle (16ms - one frame)
  static const Duration gestureThrottle = Duration(milliseconds: 16);
  
  /// Page transition duration (250ms max)
  static const Duration pageTransitionDuration = Duration(milliseconds: 250);
  
  /// Bottom sheet duration (300ms)
  static const Duration bottomSheetDuration = Duration(milliseconds: 300);
  
  /// Modal duration (200ms)
  static const Duration modalDuration = Duration(milliseconds: 200);
  
  /// Skeleton shimmer cycle (1200ms)
  static const Duration shimmerCycle = Duration(milliseconds: 1200);
  
  /// List builder threshold (20 items)
  static const int listBuilderThreshold = 20;
  
  /// Scroll preload threshold (200px)
  static const double scrollPreloadThreshold = 200.0;
  
  /// Image memory cache multiplier (2x display size)
  static const int imageCacheMultiplier = 2;
  
  /// Get skeleton loader for list item
  static Widget getSkeletonListItem() {
    return SkeletonLoaders.channelRow();
  }
  
  /// Get skeleton loader for card
  static Widget getSkeletonCard() {
    return SkeletonLoaders.movieCard();
  }
  
  /// Get skeleton loader for search result
  static Widget getSkeletonSearchResult() {
    return SkeletonLoaders.searchResult();
  }
  
  /// Check if reduce motion is enabled
  static bool isReduceMotionEnabled(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }
}

/// Performance monitoring utilities
class PerformanceMonitor {
  static final Map<String, DateTime> _timestamps = {};
  
  /// Start timing an operation
  static void start(String operation) {
    _timestamps[operation] = DateTime.now();
  }
  
  /// End timing an operation and return duration
  static Duration end(String operation) {
    final start = _timestamps[operation];
    if (start == null) return Duration.zero;
    
    final duration = DateTime.now().difference(start);
    _timestamps.remove(operation);
    
    return duration;
  }
  
  /// Log operation duration
  static void log(String operation, Duration duration) {
    // In production, send to analytics
    // In development, print to console
    // debugPrint('$operation took ${duration.inMilliseconds}ms');
  }
  
  /// Clear all timestamps
  static void clear() {
    _timestamps.clear();
  }
}

/// Memory management utilities
class MemoryManager {
  /// Clear image cache
  static Future<void> clearImageCache() async {
    // Implementation pending - requires CachedNetworkImage
    // await CachedNetworkImage.clearImageCache();
  }
  
  /// Clear all caches
  static Future<void> clearAllCaches() async {
    await clearImageCache();
  }
}

/// Frame budget utilities
class FrameBudget {
  /// Target FPS for current device
  static int get targetFPS {
    // Check device capabilities
    // 60fps minimum, 120fps on capable devices
    return 60; // Default to 60fps
  }
  
  /// Target frame duration in milliseconds
  static int get targetFrameDuration {
    return (1000 / targetFPS).round();
  }
  
  /// Check if within frame budget
  static bool isWithinBudget(Duration duration) {
    return duration.inMilliseconds < targetFrameDuration;
  }
}
