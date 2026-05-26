import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/config/ad_config.dart';
import 'package:lumio_tv/network/toffee_headers.dart';

void main() {
  test('cookieHeader omits subscriberToken when define empty', () {
    expect(AdConfig.toffeeSubscriberToken, isEmpty);
    expect(ToffeeHeaders.cookieHeader, contains('preferredLanguage=en'));
    expect(ToffeeHeaders.cookieHeader, isNot(contains('subscriberToken=eyJ')));
    expect(ToffeeHeaders.hasSubscriberToken, isFalse);
  });

  test('userAgent is non-empty Mozilla string', () {
    expect(ToffeeHeaders.userAgent, contains('Mozilla'));
    expect(ToffeeHeaders.userAgent, isNot(contains('YOUR_')));
  });
}
