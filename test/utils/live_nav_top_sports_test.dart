import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/models/model.dart';
import 'package:lumio_tv/utils/live_nav_top_sports.dart';

void main() {
  const mainCh = ChannelModel(
    id: 'm1',
    name: 'T Sports HD',
    category: 'Sports',
    country: 'BD',
    streamUrl: 'https://main-tsports.m3u8',
  );

  const gitunCh = ChannelModel(
    id: 'g1',
    name: 'Willow HD',
    category: 'GITUN',
    country: 'US',
    streamUrl: 'https://gitun-willow.m3u8',
  );

  test('T Sports from main catalog, Willow from GITUN', () {
    final top = LiveNavTopSports.build(
      mainCatalog: const [mainCh],
      gitun: const [gitunCh],
    );
    expect(top.any((c) => c.name.contains('T Sports')), isTrue);
    expect(top.any((c) => c.streamUrl.contains('gitun-willow')), isTrue);
    expect(
      top.firstWhere((c) => c.name.contains('Willow')).streamUrl,
      'https://gitun-willow.m3u8',
    );
  });

  test('pinned channels excluded from remainder check', () {
    const pinned = [
      ChannelModel(
        id: 'g1',
        name: 'Willow HD',
        category: 'Sports',
        country: 'US',
        streamUrl: 'https://gitun-willow.m3u8',
      ),
    ];
    expect(
      LiveNavTopSports.isPinned(
        const ChannelModel(
          id: 'g1',
          name: 'Willow HD',
          category: 'GITUN',
          country: 'US',
          streamUrl: 'https://gitun-willow.m3u8',
        ),
        pinned,
      ),
      isTrue,
    );
  });
}
