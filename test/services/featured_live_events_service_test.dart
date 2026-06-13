import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/services/featured_live_events_service.dart';

void main() {
  test('parses featured JSON with manual channel links', () {
    const body = '''
{
  "sectionTitle": "World Cup 2026",
  "sectionSubtitle": "Pick a channel",
  "maxCards": 3,
  "events": [
    {
      "id": "wc1",
      "sport": "football",
      "tournament": "FIFA World Cup 2026",
      "teamA": "Brazil",
      "teamB": "Argentina",
      "status": "live",
      "matchDate": "2026-06-15T18:00:00.000Z",
      "channels": [
        { "name": "T Sports HD", "url": "https://cdn.example/a.m3u8" },
        {
          "name": "Backup",
          "url": "https://cdn.example/b.m3u8",
          "alternateStreams": [
            { "url": "https://cdn.example/c.m3u8", "label": "HD" }
          ]
        }
      ]
    }
  ]
}
''';

    final root = jsonDecode(body) as Map<String, dynamic>;
    final payload = FeaturedLiveEventsPayload.fromJson(root);

    expect(payload.sectionTitle, 'World Cup 2026');
    expect(payload.events.length, 1);
    expect(payload.events.first.match.teamA, 'Brazil');
    expect(payload.events.first.tournament, 'FIFA World Cup 2026');
    expect(payload.events.first.relatedChannels.length, 2);
    expect(
      payload.events.first.relatedChannels.first.streamUrl,
      'https://cdn.example/a.m3u8',
    );
    expect(
      payload.events.first.relatedChannels.last.allStreams.length,
      greaterThan(1),
    );
  });

  test('limits to maxCards', () {
    final payload = FeaturedLiveEventsPayload.fromJson({
      'maxCards': 2,
      'events': [
        {
          'id': 'a',
          'teamA': 'A',
          'teamB': 'B',
          'channels': [
            {'name': 'X', 'url': 'https://x.m3u8'}
          ],
        },
        {
          'id': 'b',
          'teamA': 'C',
          'teamB': 'D',
          'channels': [
            {'name': 'Y', 'url': 'https://y.m3u8'}
          ],
        },
        {
          'id': 'c',
          'teamA': 'E',
          'teamB': 'F',
          'channels': [
            {'name': 'Z', 'url': 'https://z.m3u8'}
          ],
        },
      ],
    });
    expect(payload.events.length, 2);
  });
}
