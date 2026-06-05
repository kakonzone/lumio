import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/models/model.dart';
import 'package:lumio_tv/utils/channel_playback_links.dart';

void main() {
  const base = ChannelModel(
    id: 'x',
    name: 'x',
    category: 'Sports',
    country: 'Bangladesh',
    streamUrl: 'https://a.test/1.m3u8',
  );

  test('hub parent exposes all child streams in player strip', () {
    final hub = base.copyWith(
      id: 'hub_akash',
      name: 'Akash TV',
      isHubParent: true,
      hubGroupId: 'hub_akash',
      streamUrl: 'https://a.test/1.m3u8',
    );
    final child = base.copyWith(
      id: 'hub_akash_b',
      name: 'Akash Beta',
      hubGroupId: 'hub_akash',
      streamUrl: 'https://a.test/2.m3u8',
    );
    final links = ChannelPlaybackLinks.resolve(hub, [hub, child]);
    expect(links.length, 2);
    expect(links.map((l) => l.url).toList(), contains('https://a.test/2.m3u8'));
  });

  test('M3U alternates on one row pass through to player', () {
    final ch = base.copyWith(
      name: 'Star Sports 1',
      streamUrl: 'https://a.test/1.m3u8',
      alternateStreams: [
        StreamLink(url: 'https://a.test/2.m3u8', label: 'Link 2'),
      ],
    );
    expect(ChannelPlaybackLinks.resolve(ch, [ch]).length, 2);
  });

  test('same merge key peers combine when each row has one URL', () {
    final a = base.copyWith(
      id: '1',
      name: 'T Sports HD',
      streamUrl: 'https://a.test/hd.m3u8',
    );
    final b = base.copyWith(
      id: '2',
      name: 'T Sports',
      streamUrl: 'https://a.test/sd.m3u8',
    );
    final links = ChannelPlaybackLinks.resolve(a, [a, b]);
    expect(links.length, 2);
  });
}
