import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/core/player/quality_config.dart';

void main() {
  group('QualityConfig.initialFor', () {
    test('mobile + no saved pref → 540p', () {
      expect(
        QualityConfig.initialFor(isTablet: false, isDesktop: false),
        StreamQuality.p540,
      );
      expect(
        QualityConfig.initialTargetHeightPx(isTablet: false, isDesktop: false),
        540,
      );
    });

    test('tablet + no saved pref → 720p', () {
      expect(
        QualityConfig.initialFor(isTablet: true, isDesktop: false),
        StreamQuality.p720,
      );
    });
  });

  group('QualityConfig.clampForAuto', () {
    test('mobile + auto + cellular → clamps 1080p to 720p', () {
      expect(
        QualityConfig.clampForAuto(
          requested: StreamQuality.p1080,
          isMobile: true,
          isOnWifi: false,
          batteryPercent: 80,
        ),
        StreamQuality.p720,
      );
    });

    test('mobile + auto + wifi + battery 80% → allows 1080p', () {
      expect(
        QualityConfig.clampForAuto(
          requested: StreamQuality.p1080,
          isMobile: true,
          isOnWifi: true,
          batteryPercent: 80,
        ),
        StreamQuality.p1080,
      );
    });

    test('mobile + auto + wifi + battery 30% → clamps to 720p', () {
      expect(
        QualityConfig.clampForAuto(
          requested: StreamQuality.p1080,
          isMobile: true,
          isOnWifi: true,
          batteryPercent: 30,
        ),
        StreamQuality.p720,
      );
    });

    test('clampAutoHeightPx caps 1080 to 720 on cellular', () {
      expect(
        QualityConfig.clampAutoHeightPx(
          targetHeightPx: 1080,
          isMobile: true,
          isOnWifi: false,
          batteryPercent: 100,
        ),
        720,
      );
    });
  });
}
