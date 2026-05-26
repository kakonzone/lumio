import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/ads/adsterra_telemetry_client.dart';

class _RecordingTelemetryClient implements AdsterraTelemetryClient {
  final List<AdsterraTelemetryEvent> events = [];

  @override
  Future<void> send(AdsterraTelemetryEvent event) async {
    events.add(event);
  }
}

void main() {
  tearDown(() {
    AdsterraTelemetryService.instance.debugReset();
    AdsterraTelemetryService.instance.client = HttpAdsterraTelemetryClient();
  });

  test('AdsterraTelemetryEvent serializes extra when present', () {
    final json = const AdsterraTelemetryEvent(
      installId: 'id',
      fingerprint: 'fp',
      placement: 'popunder',
      format: 'popunder',
      timestampMs: 1,
      extra: {'zone': 'test'},
    ).toJson();
    expect(json['extra'], {'zone': 'test'});
  });

  test('AdsterraTelemetryEvent omits empty extra', () {
    final json = const AdsterraTelemetryEvent(
      installId: 'id',
      fingerprint: 'fp',
      placement: 'x',
      format: 'direct_link',
      timestampMs: 1,
    ).toJson();
    expect(json.containsKey('extra'), isFalse);
  });

  test('report does not throw when telemetry URL unset', () {
    expect(
      () => AdsterraTelemetryService.instance.report(
        placement: 'test',
        format: 'popunder',
      ),
      returnsNormally,
    );
  });

  test('HMAC signature is stable hex sha256', () {
    const body = '{"installId":"a"}';
    const key = 'secret';
    final sig = HttpAdsterraTelemetryClient.signBody(body, key);
    expect(sig, HttpAdsterraTelemetryClient.signBody(body, key));
    expect(sig.length, 64);
    expect(sig, matches(RegExp(r'^[0-9a-f]+$')));
  });

  test('report invokes client when debugForceConfigured', () async {
    final svc = AdsterraTelemetryService.instance;
    final recorder = _RecordingTelemetryClient();
    svc.debugReset();
    svc.debugForceConfigured = true;
    svc.debugSkipAdsterraGate = true;
    svc.client = recorder;

    svc.report(placement: 'popunder', format: 'popunder');
    await Future<void>.delayed(Duration.zero);

    expect(recorder.events, hasLength(1));
    expect(recorder.events.single.placement, 'popunder');
    expect(recorder.events.single.format, 'popunder');
    expect(recorder.events.single.installId, isNotEmpty);
    expect(recorder.events.single.fingerprint, isNotEmpty);
  });
}
