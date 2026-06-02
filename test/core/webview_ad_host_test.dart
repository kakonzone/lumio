import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/core/ads/webview_ad_host.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  test('blocks off-allowlist host', () {
    expect(
      WebViewAdHost.evaluateNavigation('https://evil.example/phish'),
      NavigationDecision.prevent,
    );
  });

  test('allows ad network host', () {
    expect(
      WebViewAdHost.evaluateNavigation('https://www.effectivecpmnetwork.com/x'),
      NavigationDecision.navigate,
    );
  });

  test('allows about:blank', () {
    expect(
      WebViewAdHost.evaluateNavigation('about:blank'),
      NavigationDecision.navigate,
    );
  });
}
