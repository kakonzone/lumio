import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Single WebView stack (smaller APK than dual webview + inappwebview).
void main() {
  test('pubspec uses webview_flutter only (no flutter_inappwebview)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('webview_flutter:'), isTrue);
    expect(pubspec.contains('flutter_inappwebview:'), isFalse);
  });

  test('pubspec.lock resolves webview_flutter when lock present', () {
    final lock = File('pubspec.lock');
    if (!lock.existsSync()) return;
    final text = lock.readAsStringSync();
    expect(text.contains('webview_flutter'), isTrue);
    expect(text.contains('flutter_inappwebview'), isFalse);
  });
}
