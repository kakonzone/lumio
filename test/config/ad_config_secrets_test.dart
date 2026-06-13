import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/config/ad_config.dart';

void main() {
  test('AdConfig monetization strings use fromEnvironment (no URL literals)',
      () {
    final source = File('lib/config/ad_config.dart').readAsStringSync();
    expect(source.contains('adsterra.com'), isFalse);
    expect(source.contains('YOUR_APP_KEY'), isFalse);
    expect(source.contains('znewe3rrge3dh03f'), isFalse);
    expect(source.contains('LEVELPLAY_APP_KEY'), isTrue);
    expect(source.contains('String.fromEnvironment'), isTrue);
  });

  test('empty defines yield hasMonetizationConfig false', () {
    // This assertion must remain stable even when the test runner is compiled
    // with local dart-defines (e.g. `--dart-define-from-file=secrets.json`).
    if (AdConfig.levelPlayAppKey.isEmpty) {
      expect(AdConfig.hasMonetizationConfig, isFalse);
    } else {
      // When defines are present, monetization config may be true or false depending on other keys.
      expect(AdConfig.levelPlayAppKey.trim().isNotEmpty, isTrue);
    }
  });

  test('dumpRedacted never prints secret values', () {
    final dump = AdConfig.dumpRedacted();
    expect(dump, contains('[AdConfig] dump'));
    expect(dump, contains('LEVELPLAY_APP_KEY='));
    expect(dump, isNot(contains('2675bcc95')));
    expect(dump.split('<set>').length + dump.split('<unset>').length,
        greaterThan(2));
  });
}
