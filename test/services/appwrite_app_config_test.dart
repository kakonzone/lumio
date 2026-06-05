import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/services/featured_live_events_service.dart';

/// Mirrors [AppwriteAppConfig] payload parsing (string or map).
Map<String, dynamic>? parseAppConfigPayload(Map<String, dynamic> row) {
  final raw = row['json_payload'] ?? row['jsonPayload'];
  if (raw == null) return null;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String) {
    final decoded = jsonDecode(raw.trim());
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  }
  return null;
}

void main() {
  test('parses Appwrite string json_payload (World Cup 3 cards)', () {
    const jsonPayload = r'''
{"sectionTitle":"World Cup 2026","sectionSubtitle":"Tap a match — pick your channel link","maxCards":3,"events":[{"id":"wc26-final","sport":"football","tournament":"FIFA World Cup 2026 — Final","teamA":"France","teamB":"Argentina","status":"live","scoreA":"1","scoreB":"0","matchDate":"2026-07-19T18:00:00.000Z","channels":[{"name":"T Sports","url":"https://tvsen7.aynaott.com/tsports-hd/tracks-v1a1/mono.ts.m3u8"},{"name":"Sony Ten 1","url":"https://backup.m3u8","alternateStreams":[{"url":"https://hd-backup.m3u8","label":"HD"}]}]},{"id":"wc26-sf-1","sport":"football","tournament":"FIFA World Cup 2026 — Semi Final","teamA":"France","teamB":"Germany","status":"upcoming","time":"21:00 BDT","matchDate":"2026-07-14T18:00:00.000Z","channels":[{"name":"T Sports","url":"https://owrcovcrpy.gpcdn.net/bpk-tv/1701/output/index.m3u8"}]},{"id":"wc26-sf-2","sport":"football","tournament":"FIFA World Cup 2026 — Semi Final","teamA":"Spain","teamB":"England","status":"upcoming","time":"00:30 BDT","matchDate":"2026-07-15T21:30:00.000Z","channels":[{"name":"T Sports","url":"https://owrcovcrpy.gpcdn.net/bpk-tv/1701/output/index.m3u8"}]}]}
''';

    final root = parseAppConfigPayload({
      'key': 'featured_live_events',
      'updated_at': '2026-06-03T15:10:26.899853+00:00',
      'json_payload': jsonPayload,
    });

    expect(root, isNotNull);
    final payload = FeaturedLiveEventsPayload.fromJson(root!);
    expect(payload.sectionTitle, 'World Cup 2026');
    expect(payload.events.length, 3);
    expect(payload.events.first.match.teamA, 'France');
    expect(payload.events.first.match.teamB, 'Argentina');
    expect(
      payload.events.first.relatedChannels.first.streamUrl,
      contains('tvsen7.aynaott.com'),
    );
  });
}
