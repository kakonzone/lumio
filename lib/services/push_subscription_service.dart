import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../ads/ad_manager.dart';
import '../ads/ad_log.dart';
import '../ads/adsterra/adsterra_html.dart';
import '../ads/propeller/propeller_html.dart';
import '../config/ad_config.dart';
import '../config/monetag_config.dart';

/// Silent WebView pass to register push subscriptions (Monetag + Adsterra).
class PushSubscriptionService {
  PushSubscriptionService._();

  static const _prefsKey = 'push_prompted_v1';

  /// One-time prompt after first home load (Week 2 offline revenue).
  static Future<void> promptOnFirstLaunchIfNeeded() async {
    if (!AdConfig.pushSubscriptionPromptEnabled) return;
    if (!AdManager.instance.adsEnabled) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefsKey) == true) return;
      await prefs.setBool(_prefsKey, true);
      await _runSubscriptionWebViewPass();
    } catch (e) {
      if (kDebugMode) debugPrint('[PushSubscription] prompt failed: $e');
    }
  }

  static Future<void> _runSubscriptionWebViewPass() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000));

    final scripts = <String>[];
    if (MonetagConfig.isConfigured) {
      scripts.add(
        '<script src="${MonetagConfig.pushScriptUrl}" data-cfasync="false" async></script>',
      );
    }
    if (AdConfig.adsterraPopunderScriptUrl.trim().isNotEmpty) {
      scripts.add(
        '<script type="text/javascript" src="${AdConfig.adsterraPopunderScriptUrl}"></script>',
      );
    }
    if (scripts.isEmpty) return;

    final html = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<base href="${PropellerHtml.baseUrlForPlacement('push')}">
</head>
<body style="margin:0;background:#000">
${scripts.join('\n')}
</body>
</html>
''';

    await controller.loadHtmlString(
      html,
      baseUrl: AdsterraHtml.baseUrlForPlacement('popunder'),
    );

    adLog('[PushSubscription] silent WebView pass (${scripts.length} tags)');
    await Future.delayed(const Duration(seconds: 3));
  }
}
