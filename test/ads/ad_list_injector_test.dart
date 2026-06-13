import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/ads/utils/ad_list_injector.dart';
import 'package:lumio_tv/config/ad_config.dart';

void main() {
  test('nativeDensityByScreen channel lists use 6-item spacing, news uses 4',
      () {
    expect(AdConfig.nativeDensityByScreen[AdListScreen.sports], 6);
    expect(AdConfig.nativeDensityByScreen[AdListScreen.live], 6);
    expect(AdConfig.nativeDensityByScreen[AdListScreen.news], 4);
    expect(AdConfig.nativeDensityByScreen[AdListScreen.categoryDrilldown], 6);
    expect(AdConfig.nativeDensityByScreen[AdListScreen.home], 6);
  });

  test('sports injects ad every 6 channels via channelListNativeInterval', () {
    expect(
      AdListInjector.isAdIndex(6,
          screen: AdListScreen.sports, intervalOverride: 6),
      isTrue,
    );
    expect(
      AdListInjector.sourceIndex(7,
          screen: AdListScreen.sports, intervalOverride: 6),
      6,
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
