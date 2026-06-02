import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/services/update_service.dart';

void main() {
  group('UpdateService.isNewerVersion', () {
    test('newer remote version', () {
      expect(UpdateService.isNewerVersion('1.0.1', '1.0.0'), isTrue);
    });

    test('same version', () {
      expect(UpdateService.isNewerVersion('2.1.0', '2.1.0'), isFalse);
    });

    test('older remote version', () {
      expect(UpdateService.isNewerVersion('1.0.0', '1.2.0'), isFalse);
    });
  });
}
