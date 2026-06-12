import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Device-aware limits: smaller APK install footprint + smoother low-RAM phones.
enum DeviceRamTier { low, normal, high }

class PerformanceTuning {
  PerformanceTuning._();

  static const _channel = MethodChannel('com.kakonzone.lumio/storage');

  static DeviceRamTier _tier = DeviceRamTier.normal;
  static bool _applied = false;

  // New simple RAM detection for ad engine optimization
  static int? _cachedTotalRamMb;
  static bool _isLowRam = false;
  static bool _isHighRam = false;

  static DeviceRamTier get tier => _tier;
  static bool get isLowRam => _tier == DeviceRamTier.low || _isLowRam;
  static bool get isHighRam => _tier == DeviceRamTier.high || _isHighRam;
  static bool get isNormalRam => !isLowRam && !isHighRam;

  /// In-memory decoded images (Flutter ImageCache).
  static int get imageCacheMaxObjects =>
      switch (_tier) {
        DeviceRamTier.low => 40,
        DeviceRamTier.normal => 80,
        DeviceRamTier.high => 120,
      };

  static int get imageCacheMaxBytes {
    if (kReleaseMode) {
      return switch (_tier) {
        DeviceRamTier.low => 8 * 1024 * 1024,   // Reduced from 16MB for better performance
        DeviceRamTier.normal => 16 * 1024 * 1024, // Reduced from 28MB
        DeviceRamTier.high => 32 * 1024 * 1024,   // Reduced from 40MB
      };
    }
    return switch (_tier) {
      DeviceRamTier.low => 12 * 1024 * 1024,
      DeviceRamTier.normal => 24 * 1024 * 1024,
      DeviceRamTier.high => 48 * 1024 * 1024,
    };
  }

  /// Disk cache for network logos / news thumbs.
  static int get diskImageCacheObjects {
    if (kReleaseMode) {
      return switch (_tier) {
        DeviceRamTier.low => 20,
        DeviceRamTier.normal => 32,
        DeviceRamTier.high => 44,
      };
    }
    return switch (_tier) {
      DeviceRamTier.low => 28,
      DeviceRamTier.normal => 48,
      DeviceRamTier.high => 64,
    };
  }

  /// ListView pre-build window — lower = less RAM, slightly more scroll work.
  static double get listCacheExtent =>
      switch (_tier) {
        DeviceRamTier.low => 150,   // Reduced from 200 for better performance
        DeviceRamTier.normal => 250, // Reduced from 320
        DeviceRamTier.high => 350,   // Reduced from 420
      };

  /// media_kit buffer (MB) — lower on 2GB phones reduces OOM during playback.
  static int get playerBufferMb =>
      switch (_tier) {
        DeviceRamTier.low => 2,
        DeviceRamTier.normal => 3,
        DeviceRamTier.high => 4,
      };

  static int get playerBufferBytes => playerBufferMb * 1024 * 1024;

  /// Call once from [main] before [runApp].
  static Future<void> apply() async {
    if (_applied) return;
    if (Platform.isAndroid) {
      _tier = await _readAndroidRamTier();
    }
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSize = imageCacheMaxObjects;
    cache.maximumSizeBytes = imageCacheMaxBytes;
    _applied = true;
    debugPrint(
      '[Performance] tier=$_tier '
      'imgCache=${imageCacheMaxObjects}/${imageCacheMaxBytes ~/ (1024 * 1024)}MB '
      'playerBuf=${playerBufferMb}MB',
    );
  }

  /// New RAM detection method for ad engine optimization
  static Future<int?> getTotalRamMb() async {
    if (_cachedTotalRamMb != null) return _cachedTotalRamMb;
    try {
      if (Platform.isAndroid) {
        final raw = await _channel.invokeMethod<Object>('getDeviceProfile');
        if (raw is! Map) return null;
        final map = Map<Object?, Object?>.from(raw);
        final mb = (map['totalRamMb'] as num?)?.toInt();
        _cachedTotalRamMb = mb;
        return mb;
      }
    } catch (_) {}
    return null;
  }

  /// Initialize simple RAM flags for ad engine use
  static Future<void> initialize() async {
    final ram = await getTotalRamMb();
    if (ram == null) return;
    _isLowRam = ram < 2048;
    _isHighRam = ram >= 6144;
    debugPrint('[Performance] RAM detection: ${ram}MB, lowRam=$_isLowRam, highRam=$_isHighRam');
  }

  static Future<DeviceRamTier> _readAndroidRamTier() async {
    try {
      final raw = await _channel.invokeMethod<Object>('getDeviceProfile');
      if (raw is! Map) return DeviceRamTier.normal;
      final map = Map<Object?, Object?>.from(raw);
      if (map['lowMemoryDevice'] == true) return DeviceRamTier.low;
      final mb = (map['totalRamMb'] as num?)?.toInt() ?? 4096;
      if (mb < 2800) return DeviceRamTier.low;
      if (mb < 5200) return DeviceRamTier.normal;
      return DeviceRamTier.high;
    } catch (_) {
      return DeviceRamTier.normal;
    }
  }
}
