import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ad_log.dart';

/// Opens HTTPS URLs in the device browser (native Intent on Android).
class ExternalUrlLauncher {
  ExternalUrlLauncher._();

  static const _channel = MethodChannel('com.kakonzone.lumio/ads');

  static Future<bool> openInBrowser(String raw) async {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme) {
      debugPrint('[ExternalUrlLauncher] invalid url');
      return false;
    }
    debugPrint('[ExternalUrlLauncher] opening host=${uri.host}');

    if (Platform.isAndroid) {
      try {
        final nativeOk = await _channel.invokeMethod<bool>(
              'openUrlInBrowser',
              <String, String>{'url': uri.toString()},
            ) ==
            true;
        if (nativeOk) {
          debugPrint('[ExternalUrlLauncher] opened via Android Intent');
          return true;
        }
        debugPrint('[ExternalUrlLauncher] native Intent returned false');
      } catch (e) {
        debugPrint('[ExternalUrlLauncher] native Intent failed: $e');
      }
    }

    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        debugPrint('[ExternalUrlLauncher] launchUrl externalApplication ok');
        return true;
      }
    } catch (e) {
      adLog('[ExternalUrlLauncher] launchUrl external failed: $e');
    }

    if (Platform.isAndroid) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.platformDefault)) {
          debugPrint('[ExternalUrlLauncher] launchUrl platformDefault ok');
          return true;
        }
      } catch (e) {
        adLog('[ExternalUrlLauncher] platformDefault failed: $e');
      }
    }

    return false;
  }
}
