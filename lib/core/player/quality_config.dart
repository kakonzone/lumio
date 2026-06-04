import 'dart:io';

import 'package:flutter/foundation.dart';

enum StreamQuality { p360, p480, p540, p720, p1080, original }

extension StreamQualityHeights on StreamQuality {
  int get targetHeightPx => switch (this) {
        StreamQuality.p360 => 360,
        StreamQuality.p480 => 480,
        StreamQuality.p540 => 540,
        StreamQuality.p720 => 720,
        StreamQuality.p1080 => 1080,
        StreamQuality.original => 0,
      };
}

class QualityConfig {
  QualityConfig._();

  /// First-launch default. Conservative for thermals.
  static const StreamQuality defaultMobile = StreamQuality.p540;
  static const StreamQuality defaultTablet = StreamQuality.p720;
  static const StreamQuality defaultDesktop = StreamQuality.p1080;

  /// Hard ceiling on mobile unless user overrides AND on wifi AND battery > 50%.
  static const StreamQuality mobileAutoCeiling = StreamQuality.p720;

  static StreamQuality initialFor({
    required bool isTablet,
    required bool isDesktop,
  }) {
    if (isDesktop) return defaultDesktop;
    if (isTablet) return defaultTablet;
    return defaultMobile;
  }

  static int initialTargetHeightPx({
    required bool isTablet,
    required bool isDesktop,
  }) =>
      initialFor(isTablet: isTablet, isDesktop: isDesktop).targetHeightPx;

  static StreamQuality clampForAuto({
    required StreamQuality requested,
    required bool isMobile,
    required bool isOnWifi,
    required int batteryPercent,
  }) {
    if (!isMobile) return requested;
    final allowHigh = isOnWifi && batteryPercent > 50;
    if (allowHigh) return requested;
    if (_rank(requested) > _rank(mobileAutoCeiling)) {
      return mobileAutoCeiling;
    }
    return requested;
  }

  /// Clamps auto-mode rendition height (pixels) for mobile thermals.
  static int clampAutoHeightPx({
    required int targetHeightPx,
    required bool isMobile,
    required bool isOnWifi,
    required int batteryPercent,
  }) {
    if (targetHeightPx <= 0 || !isMobile) return targetHeightPx;
    final allowHigh = isOnWifi && batteryPercent > 50;
    if (allowHigh) return targetHeightPx;
    final ceiling = mobileAutoCeiling.targetHeightPx;
    return targetHeightPx > ceiling ? ceiling : targetHeightPx;
  }

  static bool get isMobilePlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static int _rank(StreamQuality q) => switch (q) {
        StreamQuality.p360 => 1,
        StreamQuality.p480 => 2,
        StreamQuality.p540 => 3,
        StreamQuality.p720 => 4,
        StreamQuality.p1080 => 5,
        StreamQuality.original => 6,
      };
}
