import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/services/fraud/vpn_asn_catalog.dart';
import 'package:lumio_tv/services/fraud/vpn_detector.dart';

void main() {
  test('VpnAsnCatalog has curated unique ASNs', () {
    expect(VpnAsnCatalog.top50.length, 51);
  });

  group('VpnDetector.score — three tiers', () {
    test('clean — no signals', () {
      const input = VpnDetectionInput(
        vpnInterfaceDetected: false,
        vpnTransportDetected: false,
        dnsLeakSuspicious: false,
        vpnAppInstalled: false,
        localeMismatch: false,
        tzMismatch: false,
      );
      final r = VpnDetector.score(input);
      expect(r.confidence, 0.0);
      expect(r.tier, VpnConfidenceTier.clean);
      expect(r.preferCleanSdkRouting, isFalse);
    });

    test('suspected — DNS + locale, no tunnel (single legacy signal)', () {
      const input = VpnDetectionInput(
        vpnInterfaceDetected: false,
        vpnTransportDetected: false,
        dnsLeakSuspicious: true,
        vpnAppInstalled: false,
        localeMismatch: true,
        tzMismatch: false,
      );
      final r = VpnDetector.score(input);
      expect(r.confidence, closeTo(0.37, 0.001));
      expect(r.tier, VpnConfidenceTier.suspected);
      expect(r.preferCleanSdkRouting, isFalse);
    });

    test('confirmed — tun + VPN transport', () {
      const input = VpnDetectionInput(
        vpnInterfaceDetected: true,
        vpnTransportDetected: true,
        dnsLeakSuspicious: false,
        vpnAppInstalled: false,
        localeMismatch: false,
        tzMismatch: false,
      );
      final r = VpnDetector.score(input);
      expect(r.confidence, closeTo(0.75, 0.001));
      expect(r.tier, VpnConfidenceTier.confirmed);
      expect(r.preferCleanSdkRouting, isTrue);
    });
  });

  test('legacy two-signal rule still routes clean SDK', () {
    const input = VpnDetectionInput(
      vpnInterfaceDetected: false,
      vpnTransportDetected: false,
      dnsLeakSuspicious: false,
      vpnAppInstalled: false,
      localeMismatch: true,
      tzMismatch: true,
    );
    final r = VpnDetector.score(input);
    expect(r.confidence, lessThan(VpnDetector.routingThreshold));
    expect(r.preferCleanSdkRouting, isTrue);
  });
}
