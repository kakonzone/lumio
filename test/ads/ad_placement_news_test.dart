import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/ads/ad_placement_news.dart';

void main() {
  group('AdPlacementNews injection', () {
    test('injects after every 5th article when ads on', () {
      expect(
        AdPlacementNews.countInjectedAds(
          articleCount: 10,
          interval: 5,
          adsOn: true,
        ),
        2,
      );
      expect(AdPlacementNews.shouldInjectAdAt(4, 5, adsOn: true), isTrue);
      expect(AdPlacementNews.shouldInjectAdAt(3, 5, adsOn: true), isFalse);
    });

    test('injects every 4th article when aggressive interval', () {
      expect(
        AdPlacementNews.countInjectedAds(
          articleCount: 12,
          interval: 4,
          adsOn: true,
        ),
        3,
      );
      expect(AdPlacementNews.shouldInjectAdAt(3, 4, adsOn: true), isTrue);
    });

    test('no injection when ads off', () {
      expect(
        AdPlacementNews.countInjectedAds(
          articleCount: 20,
          interval: 5,
          adsOn: false,
        ),
        0,
      );
    });
  });
}
