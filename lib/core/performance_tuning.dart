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

  static DeviceRamTier get tier => _tier;
  static bool get isLowRam => _tier == DeviceRamTier.low;
  static bool get isHighRam => _tier == DeviceRamTier.high;

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
        DeviceRamTier.low => 16 * 1024 * 1024,
        DeviceRamTier.normal => 28 * 1024 * 1024,
        DeviceRamTier.high => 40 * 1024 * 1024,
      };
    }
    return switch (_tier) {
      DeviceRamTier.low => 24 * 1024 * 1024,
      DeviceRamTier.normal => 48 * 1024 * 1024,
      DeviceRamTier.high => 72 * 1024 * 1024,
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
        DeviceRamTier.low => 200,
        DeviceRamTier.normal => 320,
        DeviceRamTier.high => 420,
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
