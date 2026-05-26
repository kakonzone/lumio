import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Task 11 — `flutter_inappwebview` must not be a dependency.
void main() {
  test('pubspec does not depend on flutter_inappwebview', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('flutter_inappwebview:'), isFalse);
    expect(pubspec.contains('webview_flutter:'), isTrue);
  });

  test('pubspec.lock does not resolve flutter_inappwebview', () {
    final lock = File('pubspec.lock');
    if (!lock.existsSync()) return;
    final text = lock.readAsStringSync();
    expect(text.contains('flutter_inappwebview'), isFalse);
  });
}
