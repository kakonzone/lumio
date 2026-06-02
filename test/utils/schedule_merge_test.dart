import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/models/model.dart';
import 'package:lumio_tv/utils/schedule_merge.dart';

void main() {
  test('mergeMatches dedupes same teams on same day', () {
    final footy = MatchModel(
      id: 'footystream_today_x',
      sport: 'Football',
      teamA: 'Bulgaria',
      teamB: 'Montenegro',
      status: 'upcoming',
      time: '22:00',
      channel: 'Friendly',
      matchDate: DateTime(2026, 6, 1, 16),
      scoreSource: 'FootyStream',
      teamALogo: 'https://a.logo',
    );
    final espn = MatchModel(
      id: 'espn_1',
      sport: 'Football',
      teamA: 'Bul',
      teamB: 'Montenegro',
      status: 'live',
      scoreA: '1',
      scoreB: '0',
      time: '45\'',
      channel: 'Friendly',
      matchDate: DateTime(2026, 6, 1, 16, 30),
      scoreSource: 'ESPN',
    );

    final merged = ScheduleMerge.mergeMatches([
      [footy],
      [espn],
    ]);
    expect(merged.length, 1);
    expect(merged.first.status, 'live');
    expect(merged.first.scoreA, '1');
    expect(merged.first.teamALogo, contains('a.logo'));
    expect(merged.first.scoreSource, contains('FootyStream'));
    expect(merged.first.scoreSource, contains('ESPN'));
  });
}
