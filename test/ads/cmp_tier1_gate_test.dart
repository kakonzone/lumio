import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/ads/cmp_tier1_gate.dart';

void main() {
  test('tier-1 gate off when CMP_LICENSED_ENABLED', () {
    // Compile-time flag defaults false; device locale may vary in CI.
    expect(CmpTier1Gate.cmpLicensedEnabled, isFalse);
  });

  test('BD SIM does not block ads when locale is GB', () {
    expect(
      CmpTier1Gate.blocksAdSdkInitFor(
        localeCountry: 'gb',
        simCountry: 'BD',
        networkCountry: 'BD',
      ),
      isFalse,
    );
  });

  test('GB locale without BD SIM still blocks', () {
    expect(
      CmpTier1Gate.blocksAdSdkInitFor(
        localeCountry: 'gb',
        simCountry: null,
        networkCountry: null,
      ),
      isTrue,
    );
  });
}
