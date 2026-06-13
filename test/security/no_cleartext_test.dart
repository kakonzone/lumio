import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/core/network/cleartext_allowlist.dart';

void main() {
  test('no unexpected http:// literals in lib/', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue);

    final violations = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll('\\', '/');
      if (CleartextAllowlist.paths.any(normalized.endsWith)) continue;

      final content = entity.readAsStringSync();
      if (content.contains('http://')) {
        violations.add(normalized);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Move http URLs to HTTPS or add path to cleartext_allowlist.dart: '
          '${violations.join(', ')}',
    );
  });
}
