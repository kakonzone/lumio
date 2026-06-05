import 'dart:io';

import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Shared WebView setup. Disk cache is trimmed by [AppStorageGuard] on Android.
Future<WebViewController> createLumioWebViewController({
  bool aggressiveNoCache = false,
}) async {
  late final PlatformWebViewControllerCreationParams params;
  if (Platform.isAndroid && WebViewPlatform.instance is AndroidWebViewPlatform) {
    params = AndroidWebViewControllerCreationParams();
  } else {
    params = const PlatformWebViewControllerCreationParams();
  }

  final controller = WebViewController.fromPlatformCreationParams(params);

  if (Platform.isAndroid && controller.platform is AndroidWebViewController) {
    final android = controller.platform as AndroidWebViewController;
    await android.setMediaPlaybackRequiresUserGesture(false);
    if (aggressiveNoCache) {
      // Background ad rotator — avoid persisting heavy third-party pages.
      await android.clearCache();
    }
  }

  return controller;
}

Future<void> disposeLumioWebView(WebViewController? controller) async {
  if (controller == null) return;
  try {
    await controller.loadRequest(Uri.parse('about:blank'));
  } catch (_) {}
  try {
    await controller.clearCache();
    await controller.clearLocalStorage();
  } catch (_) {}
}
