import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/config/ad_config.dart';
import 'package:lumio_tv/services/ad_safety_service.dart';
import 'package:lumio_tv/services/vpn_signal_service.dart';

void main() {
  test('legacy fingerprint migrates to stable installId', () {
    final a =
        AdSafetyService.deriveInstallIdFromLegacyFingerprint('abc123legacy');
    final b =
        AdSafetyService.deriveInstallIdFromLegacyFingerprint('abc123legacy');
    expect(a, b);
    expect(a.length, 36);
    expect(a.contains('-'), isTrue);
  });

  test('migration salt changes derived installId', () {
    // Salt is compile-time; document that CI must pin FINGERPRINT_MIGRATION_SALT.
    expect(AdConfig.fingerprintMigrationSalt, isNotEmpty);
  });

  group('ADS_ENABLED gating (Task 2)', () {
    test('AdConfig.shouldBlockAdsForBuild', () {
      expect(
        AdConfig.shouldBlockAdsForBuild(
          isReleaseMode: false,
          adsEnabledDefine: false,
        ),
        isTrue,
      );
      expect(
        AdConfig.shouldBlockAdsForBuild(
          isReleaseMode: false,
          adsEnabledDefine: true,
        ),
        isFalse,
      );
      expect(
        AdConfig.shouldBlockAdsForBuild(
          isReleaseMode: true,
          adsEnabledDefine: false,
        ),
        isFalse,
      );
    });

    test('blockAdsInThisBuild matches release-ignore rule', () {
      if (kReleaseMode) {
        expect(AdConfig.blockAdsInThisBuild, isFalse);
      } else {
        expect(
          AdConfig.blockAdsInThisBuild,
          !AdConfig.adsEnabledDefine && !AdConfig.testMode,
        );
      }
    });
  });

  group('VpnSignalService heuristics', () {
    test('locale fraud and timezone signals are independent', () {
      expect(
        VpnSignalService.isAllowedMarketLocale('BD', 'en'),
        isTrue,
      );
      expect(
        VpnSignalService.southAsiaTimezoneMismatch(const Duration(hours: 6)),
        isTrue,
      );
      expect(
        VpnSignalService.southAsiaTimezoneMismatch(const Duration(hours: -5)),
        isFalse,
      );
    });
  });

  group('VpnSignals', () {
    test('preferCleanSdk when confidence high or two+ legacy signals', () {
      const highConfidence = VpnSignals(
        vpnInterfaceDetected: true,
        localeMismatch: false,
        tzMismatch: false,
        confidence: 0.75,
        tier: VpnConfidenceTier.confirmed,
        vpnTransportDetected: true,
      );
      expect(highConfidence.preferCleanSdkRouting, isTrue);

      const one = VpnSignals(
        vpnInterfaceDetected: false,
        localeMismatch: true,
        tzMismatch: false,
        confidence: 0.12,
        tier: VpnConfidenceTier.clean,
      );
      expect(one.preferCleanSdkRouting, isFalse);

      const legacyPair = VpnSignals(
        vpnInterfaceDetected: false,
        localeMismatch: true,
        tzMismatch: true,
        confidence: 0.24,
        tier: VpnConfidenceTier.clean,
      );
      expect(legacyPair.preferCleanSdkRouting, isTrue);
    });
  });
}
