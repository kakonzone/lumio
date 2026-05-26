import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/services/vpn_signal_service.dart';

void main() {
  group('VpnSignalService.evaluateLocaleFraud', () {
    test('BD SIM + EN locale must NOT flag', () {
      expect(
        VpnSignalService.evaluateLocaleFraud(
          simCountry: 'BD',
          telephonyCountry: 'BD',
          ipGeoCountry: null,
          localeCountry: 'BD',
          localeLanguage: 'en',
          strictness: 'loose',
        ),
        isFalse,
      );
    });

    test('US SIM + RU locale + BD IP must flag (loose)', () {
      expect(
        VpnSignalService.evaluateLocaleFraud(
          simCountry: 'US',
          telephonyCountry: 'US',
          ipGeoCountry: 'BD',
          localeCountry: 'RU',
          localeLanguage: 'ru',
          strictness: 'loose',
        ),
        isTrue,
      );
    });

    test('unknown SIM must NOT flag', () {
      expect(
        VpnSignalService.evaluateLocaleFraud(
          simCountry: null,
          telephonyCountry: 'BD',
          ipGeoCountry: 'BD',
          localeCountry: 'US',
          localeLanguage: 'en',
          strictness: 'strict',
        ),
        isFalse,
      );
    });
  });
}
