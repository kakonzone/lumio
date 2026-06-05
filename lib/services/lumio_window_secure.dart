import 'dart:io';

import 'package:flutter/services.dart';

/// Android window [FLAG_SECURE] — blocks screen capture but also disables PiP.
class LumioWindowSecure {
  LumioWindowSecure._();

  static const _channel = MethodChannel('com.kakonzone.lumio/ads');

  static Future<void> setSecure(bool secure) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setWindowSecure', {'secure': secure});
    } catch (_) {}
  }
}
