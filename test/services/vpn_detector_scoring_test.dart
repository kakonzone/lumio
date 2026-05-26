import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/services/fraud/vpn_detector.dart';

/// L5 — additional confidence scoring cases.
void main() {
  test('vpn app installed adds asn_or_vpn_app weight', () {
    const input = VpnDetectionInput(
      vpnInterfaceDetected: false,
      vpnTransportDetected: false,
      dnsLeakSuspicious: false,
      vpnAppInstalled: true,
      localeMismatch: false,
      tzMismatch: false,
    );
    final r = VpnDetector.score(input);
    expect(r.confidence, closeTo(0.20, 0.001));
    expect(r.breakdown.containsKey('asn_or_vpn_app'), isTrue);
  });

  test('routing threshold boundary at 0.55', () {
    const below = VpnDetectionInput(
      vpnInterfaceDetected: false,
      vpnTransportDetected: false,
      dnsLeakSuspicious: true,
      vpnAppInstalled: true,
      localeMismatch: true,
      tzMismatch: false,
    );
    final r = VpnDetector.score(below);
    expect(r.confidence, closeTo(0.57, 0.001));
    expect(r.preferCleanSdkRouting, isTrue);
  });
}
