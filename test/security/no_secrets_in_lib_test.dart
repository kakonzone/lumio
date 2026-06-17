import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// R01 — fail CI if JWT/Bearer literals reappear under lib/.
void main() {
  test('lib/ contains no hardcoded JWT subscriber tokens or Bearer secrets',
      () {
    final libRoot = Directory('lib');
    expect(libRoot.existsSync(), isTrue);

    final violations = <String>[];
    final jwtPrefix = RegExp(r'eyJhbGciOi[A-Za-z0-9_-]{10,}');
    final subscriberJwt = RegExp(
      r'''subscriberToken\s*=\s*['"]eyJ''',
    );
    final bearerSecret = RegExp(r'Bearer\s+[A-Za-z0-9._-]{20,}');

    for (final entity in libRoot.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final loc = '${entity.path}:${i + 1}';
        if (jwtPrefix.hasMatch(line)) violations.add('$loc jwt_literal');
        if (subscriberJwt.hasMatch(line)) {
          violations.add('$loc subscriberToken_jwt');
        }
        if (bearerSecret.hasMatch(line)) violations.add('$loc bearer_literal');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Remove secrets; use dart-define (TOFFEE_SUBSCRIBER_TOKEN):\n'
          '${violations.join('\n')}',
    );
  });

  test('lib/ contains no hardcoded RapidAPI keys', () {
    final libRoot = Directory('lib');
    expect(libRoot.existsSync(), isTrue);

    final violations = <String>[];
    final rapidApiKey = RegExp(r'[a-f0-9]{32,}.*rapidapi', caseSensitive: false);

    for (final entity in libRoot.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final loc = '${entity.path}:${i + 1}';
        if (rapidApiKey.hasMatch(line)) violations.add('$loc rapidapi_key');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Remove RapidAPI keys; use dart-define (CRICBUZZ_RAPID_API_KEY):\n'
          '${violations.join('\n')}',
    );
  });

  test('lib/ contains no hardcoded effectivecpmnetwork.com URLs with keys',
      () {
    final libRoot = Directory('lib');
    expect(libRoot.existsSync(), isTrue);

    final violations = <String>[];
    final effectivecpmUrl =
        RegExp(r'effectivecpmnetwork\.com/[a-f0-9]+');

    for (final entity in libRoot.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final loc = '${entity.path}:${i + 1}';
        if (effectivecpmUrl.hasMatch(line)) {
          violations.add('$loc effectivecpmnetwork_url_with_key');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Remove effectivecpmnetwork.com URLs with keys; use dart-define (ADSTERRA_DL_*):\n'
          '${violations.join('\n')}',
    );
  });

  test('lib/ contains no hardcoded URL parameters with long keys', () {
    final libRoot = Directory('lib');
    expect(libRoot.existsSync(), isTrue);

    final violations = <String>[];
    final urlKeyParam = RegExp(r'key=[a-f0-9]{20,}');

    for (final entity in libRoot.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final loc = '${entity.path}:${i + 1}';
        if (urlKeyParam.hasMatch(line)) violations.add('$loc url_key_parameter');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Remove URL parameters with long keys; use dart-define:\n'
          '${violations.join('\n')}',
    );
  });
}
