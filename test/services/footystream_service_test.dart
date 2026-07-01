import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/services/footystream_service.dart';

void main() {
  test('parseEventsHtml extracts teams and kickoff', () {
    const html = '''
<div class="text-white font-semibold text-sm">Friendly</div>
<a href="https://footystream.pk/events/bulgaria-vs-montenegro">
<div data-start="2026-06-01T16:00:00.000Z" data-end="2026-06-01T18:10:00.000Z"></div>
<img src="https://cdn.img4every1.org/team/bulgaria/logo.webp" alt="Bulgaria">
<img src="https://cdn.img4every1.org/team/montenegro/logo.webp" alt="Montenegro">
</a>
''';
    final matches = FootyStreamService.parseEventsHtml(html);
    expect(matches.length, 1);
    expect(matches.first.teamA, 'Bulgaria');
    expect(matches.first.teamB, 'Montenegro');
    expect(matches.first.channel, 'Friendly');
    expect(matches.first.scoreSource, 'FootyStream');
    expect(matches.first.streamUrl,
        'https://footystream.pk/events/bulgaria-vs-montenegro');
  });
}
