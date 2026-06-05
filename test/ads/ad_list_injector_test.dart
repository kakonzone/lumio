import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/ads/utils/ad_list_injector.dart';
import 'package:lumio_tv/config/ad_config.dart';

void main() {
  test('nativeDensityByScreen channel lists use 8-item spacing', () {
    expect(AdConfig.nativeDensityByScreen[AdListScreen.sports], 8);
    expect(AdConfig.nativeDensityByScreen[AdListScreen.live], 8);
    expect(AdConfig.nativeDensityByScreen[AdListScreen.news], 5);
    expect(AdConfig.nativeDensityByScreen[AdListScreen.categoryDrilldown], 8);
    expect(AdConfig.nativeDensityByScreen[AdListScreen.home], 6);
  });

  test('sports injects ad every 8 channels via channelListNativeInterval', () {
    expect(
      AdListInjector.isAdIndex(8, screen: AdListScreen.sports),
      isTrue,
    );
    expect(
      AdListInjector.sourceIndex(9, screen: AdListScreen.sports),
      8,
    );
  });

  test('placement prefixes are stable per category and sport', () {
    expect(
      AdListInjector.placementPrefixForCategory('Bangla'),
      'category_list_bangla',
    );
    expect(
      AdListInjector.placementPrefixForSport('Formula 1'),
      'sports_list_formula_1',
    );
    expect(AdListInjector.defaultUseWebViewPool(AdListScreen.sports), isFalse);
    expect(
      AdListInjector.defaultUseWebViewPool(AdListScreen.favorites),
      isTrue,
    );
  });
}
