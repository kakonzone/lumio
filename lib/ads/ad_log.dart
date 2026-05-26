import 'package:flutter/foundation.dart';

/// Non-release ad-layer logging (no [kDebugMode] — use dart-define gating instead).
void adLog(String message) {
  if (!kReleaseMode) {
    debugPrint(message);
  }
}
