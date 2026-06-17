import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../ads/utils/lumio_webview_config.dart';
import '../../utils/stream_url_upgrade.dart';
import '../../config/monetag_config.dart';

/// Single entry for visible ad WebViews (Adsterra + Monetag HTML).
class WebViewAdHost {
  WebViewAdHost._();

  static const _allowedHosts = <String>{
    'www.effectivecpmnetwork.com',
    'effectivecpmnetwork.com',
    'nap5k.com',
    'monetag.local',
    'localhost',
  };

  static bool isHostAllowed(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'about' || scheme == 'data') return true;
    if (scheme != 'https' && scheme != 'http') return false;
    final host = uri.host.toLowerCase();
    if (_allowedHosts.contains(host)) return true;
    for (final suffix in _allowedHosts) {
      if (host.endsWith('.$suffix')) return true;
    }
    final monetagHosts = [
      MonetagConfig.onclickScriptHost,
      MonetagConfig.vignetteScriptHost,
      MonetagConfig.inPagePushHost,
    ];
    for (final raw in monetagHosts) {
      final h = Uri.tryParse(raw)?.host.toLowerCase();
      if (h != null && h.isNotEmpty && host == h) return true;
    }
    return false;
  }

  static NavigationDecision evaluateNavigation(String url) {
    if (StreamUrlUpgrade.isBlockedNavigationUrl(url)) {
      if (kDebugMode) {
        debugPrint('[WebViewAdHost] blocked scheme/path: $url');
      }
      return NavigationDecision.prevent;
    }
    if (!isHostAllowed(url)) {
      if (kDebugMode) {
        debugPrint('[WebViewAdHost] blocked navigation: $url');
      }
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  static Future<WebViewController> createController() async {
    final controller = await createLumioWebViewController();
    if (Platform.isAndroid && controller.platform is AndroidWebViewController) {
      final android = controller.platform as AndroidWebViewController;
      await android.setMediaPlaybackRequiresUserGesture(false);
    }
    
    // Harden WebView with anti-detection measures
    await _hardenWebView(controller);
    
    return controller;
  }
  
  static Future<void> _hardenWebView(WebViewController controller) async {
    // Inject anti-detection JavaScript before page load
    final antiDetectionJs = '''
(function(){
  // Chrome object spoof
  if (!window.chrome) {
    window.chrome = {};
  }
  if (!window.chrome.runtime) {
    window.chrome.runtime = {};
  }
  window.chrome.loadTimes = function() { return {}; };
  window.chrome.csi = function() { return {}; };
  
  // navigator.webdriver override
  Object.defineProperty(navigator, 'webdriver', {
    get: function() { return undefined; },
    configurable: true
  });
  
  // navigator.languages spoof
  Object.defineProperty(navigator, 'languages', {
    get: function() { return ['en-IN', 'en']; },
    configurable: true
  });
  
  // Remove automation indicators
  delete navigator.__proto__.webdriver;
})();
''';
    
    await controller.runJavaScript(antiDetectionJs);
    
    // Set custom User-Agent matching rotated UA
    // Note: This is set per-instance in background_ad_host.dart
    // Here we ensure WebView allows custom UA injection
    
    // Enable third-party cookies for ad networks
    // Android 5.0+ allows third-party cookies by default
    // No additional action needed for Lollipop+
  }
}
