import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/ads/utils/ad_list_injector.dart';
import 'package:lumio_tv/config/ad_config.dart';

void main() {
  test('nativeDensityByScreen matches Week 2 spec', () {
    expect(AdConfig.nativeDensityByScreen[AdListScreen.sports], 4);
    expect(AdConfig.nativeDensityByScreen[AdListScreen.live], 6);
    expect(AdConfig.nativeDensityByScreen[AdListScreen.news], 5);
    expect(AdConfig.nativeDensityByScreen[AdListScreen.categoryDrilldown], 12);
    expect(AdConfig.nativeDensityByScreen[AdListScreen.home], 6);
  });

  test('sports injects ad every 4 channels', () {
    expect(
      AdListInjector.isAdIndex(4, screen: AdListScreen.sports),
      isTrue,
    );
    expect(
      AdListInjector.sourceIndex(5, screen: AdListScreen.sports),
      4,
    );
  });
}
