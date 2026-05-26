import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/services/firebase_bootstrap.dart';

void main() {
  test('crashlytics not wired when firebase unavailable', () async {
    await FirebaseBootstrap.wireCrashlyticsForTest(firebaseAvailable: false);
    expect(FirebaseBootstrap.isInitialized, isFalse);
    expect(FirebaseBootstrap.crashlyticsWired, isFalse);
  });
}
