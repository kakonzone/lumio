import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../ads/utils/lumio_webview_config.dart';
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
      await android.setMixedContentMode(MixedContentMode.neverAllow);
      await android.setMediaPlaybackRequiresUserGesture(false);
    }
    return controller;
  }
}
