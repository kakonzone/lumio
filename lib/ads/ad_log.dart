import 'package:flutter/foundation.dart';
import '../core/logging/safe_logger.dart';

/// Ad-layer logging. Key tags also print in release for device logcat grep.
void adLog(String message) {
  final releaseVisible = kReleaseMode &&
      (message.startsWith('[LumioAds]') ||
          message.startsWith('[Unity]') ||
          message.startsWith('[ServerCap]') ||
          message.startsWith('[Placement]') ||
          message.startsWith('[AdWaterfall]') ||
          message.startsWith('[Cap]') ||
          message.startsWith('[Adsterra]'));
  if (!kReleaseMode) {
    SafeLogger.debug('ads', message);
    return;
  }
  if (releaseVisible) {
    // ignore: avoid_print
    print(message);
  }
}
