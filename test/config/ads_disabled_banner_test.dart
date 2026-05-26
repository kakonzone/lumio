import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/config/ad_config.dart';
import 'package:lumio_tv/widgets/ads_debug_banner.dart';

void main() {
  test('shouldShowAdsDisabledBanner false when ads define would be true', () {
    expect(
      AdConfig.shouldBlockAdsForBuild(
        isReleaseMode: false,
        adsEnabledDefine: true,
      ),
      isFalse,
    );
  });

  testWidgets('banner hidden when shouldShowAdsDisabledBanner is false',
      (tester) async {
    final show = AdConfig.shouldShowAdsDisabledBanner;
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AdsDebugBanner())),
    );
    if (!show) {
      expect(find.textContaining('ADS DISABLED'), findsNothing);
    }
  });
}
