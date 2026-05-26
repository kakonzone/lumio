import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/ads/analytics/ad_analytics.dart';

void main() {
  test('lumio event names do not collide with Firebase reserved list', () {
    for (final name in AdAnalytics.lumioEventNames) {
      expect(
        AdAnalytics.isReservedEventName(name),
        isFalse,
        reason: '$name is reserved by Firebase',
      );
    }
  });

  test('lumio_ad_click and lumio_ad_impression are not reserved', () {
    expect(AdAnalytics.isReservedEventName('lumio_ad_click'), isFalse);
    expect(AdAnalytics.isReservedEventName('lumio_ad_impression'), isFalse);
    expect(AdAnalytics.isReservedEventName('ad_click'), isTrue);
    expect(AdAnalytics.isReservedEventName('ad_impression'), isTrue);
  });
}
