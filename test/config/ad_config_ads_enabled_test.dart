import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/config/ad_config.dart';

void main() {
  test('blockAdsInThisBuild uses ADS_ENABLED define in non-release', () {
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
}
