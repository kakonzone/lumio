import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/services/firebase_bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initialize completes without throwing', () async {
    await FirebaseBootstrap.initialize();
    // With or without google-services.json in CI — must not throw.
    expect(FirebaseBootstrap.isInitialized, isA<bool>());
  });
}
