import '../config/ad_config.dart';

/// Canonical Toffee stream request headers (R01 / R03).
///
/// Subscriber JWT is never stored in source — only via
/// `--dart-define=TOFFEE_SUBSCRIBER_TOKEN` ([AdConfig.toffeeSubscriberToken]).
class ToffeeHeaders {
  ToffeeHeaders._();

  static const String userAgent = 'Mozilla/5.0 (Linux; Android 10; K) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Mobile Safari/537.36';

  static const _cookiePrefix = 'preferredLanguage=en; '
      '__uzma=bab6b073-2e6e-4929-8c3d-a5a8e41b44cf; '
      '__uzmb=1714992554; '
      '__uzme=2416';

  /// Full `Cookie` header value for Toffee CDN requests.
  static String get cookieHeader {
    final token = AdConfig.toffeeSubscriberToken.trim();
    if (token.isEmpty) return _cookiePrefix;
    return '$_cookiePrefix; subscriberToken=$token';
  }

  static bool get hasSubscriberToken =>
      AdConfig.toffeeSubscriberToken.trim().isNotEmpty;
}
