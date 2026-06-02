import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/services/app_update_service.dart';

void main() {
  group('AppUpdateService.isNewerVersion', () {
    test('detects patch bump', () {
      expect(AppUpdateService.isNewerVersion('1.0.1', '1.0.0'), isTrue);
    });

    test('same version is not newer', () {
      expect(AppUpdateService.isNewerVersion('2.1.0', '2.1.0'), isFalse);
    });

    test('older remote is not newer', () {
      expect(AppUpdateService.isNewerVersion('1.0.0', '1.2.0'), isFalse);
    });
  });
}
