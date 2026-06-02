import 'package:flutter/foundation.dart';

/// Ad-layer logging. Key tags also print in release for device logcat grep.
void adLog(String message) {
  final releaseVisible = kReleaseMode &&
      (message.startsWith('[LumioAds]') ||
          message.startsWith('[LevelPlay]') ||
          message.startsWith('[ServerCap]') ||
          message.startsWith('[Placement]') ||
          message.startsWith('[AdWaterfall]') ||
          message.startsWith('[Cap]') ||
          message.startsWith('[Adsterra]'));
  if (!kReleaseMode) {
    debugPrint(message);
    return;
  }
  if (releaseVisible) {
    // ignore: avoid_print
    print(message);
  }
}
