import 'package:flutter/foundation.dart';

class SafeLogger {
  static void debug(String tag, Object? message) {
    if (kDebugMode) {
      debugPrint('[$tag] $message');
    }
  }

  static void warn(String tag, Object? message) {
    if (kDebugMode) {
      debugPrint('[WARN][$tag] $message');
    }
  }

  static void error(String tag, Object? message, [Object? error, StackTrace? st]) {
    if (kDebugMode) {
      debugPrint('[ERROR][$tag] $message ${error ?? ''}');
      if (st != null) debugPrint(st.toString());
    }
    // Hook for crash reporting can be added later.
  }
}
