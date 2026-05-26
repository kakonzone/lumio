import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/ads/adsterra/adsterra_webview.dart';

void main() {
  test('disposed before paint suppresses impression telemetry', () {
    expect(
      AdsterraWebView.shouldSuppressImpression(
        disposed: true,
        hasPainted: false,
        loadLogged: false,
      ),
      isTrue,
    );
    expect(
      AdsterraWebView.shouldSuppressImpression(
        disposed: false,
        hasPainted: true,
        loadLogged: false,
      ),
      isFalse,
    );
    expect(
      AdsterraWebView.shouldSuppressImpression(
        disposed: false,
        hasPainted: true,
        loadLogged: true,
      ),
      isTrue,
    );
  });
}
