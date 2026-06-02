import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/security/ssl_pinning.dart';

void main() {
  group('SslPinning.spkiSha256Base64', () {
    test('stable hash for known bytes', () {
      final hash = SslPinning.spkiSha256Base64([1, 2, 3, 4]);
      expect(hash, isNotEmpty);
      expect(hash, SslPinning.spkiSha256Base64([1, 2, 3, 4]));
    });
  });

  group('SslPinning.validateCertificate', () {
    test('non-release skips pinning (returns true)', () {
      expect(
        SslPinning.validateCertificate(null, 'api.example.com'),
        isTrue,
      );
    });
  });
}
