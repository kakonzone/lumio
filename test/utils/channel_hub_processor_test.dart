import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/models/model.dart';
import 'package:lumio_tv/utils/channel_hub_processor.dart';

void main() {
  test('splits Akash TV multi-link blob into hub + named children', () {
    const urls = [
      'https://nomawnoijl.gpcdn.net/akash/originals/playlist.m3u8',
      'https://nomawnoijl.gpcdn.net/akash/cineedge/playlist.m3u8',
      'https://nomawnoijl.gpcdn.net/akash/kidsstars/playlist.m3u8',
    ];
    final merged = ChannelModel(
      id: 'm3u_1',
      name: 'Akash TV',
      category: 'Entertainment',
      country: 'India',
      streamUrl: urls[0],
      alternateStreams: [
        StreamLink(url: urls[1], label: 'Link 2'),
        StreamLink(url: urls[2], label: 'Link 3'),
      ],
    );

    final out = ChannelHubProcessor.expand([merged]);
    expect(out.length, 4);
    expect(out.where((c) => c.isHubParent).length, 1);
    expect(out.any((c) => c.name == 'Akash Originals'), isTrue);
    expect(out.any((c) => c.name == 'Akash Cineedge'), isTrue);
    expect(out.any((c) => c.hubGroupId == 'hub_akash'), isTrue);
  });

  test('playerRelated returns hub children for hub parent', () {
    const hub = ChannelModel(
      id: 'hub_test',
      name: 'Test Hub',
      category: 'Entertainment',
      country: 'India',
      streamUrl: 'https://x.test/hub/a/1.m3u8',
      isHubParent: true,
      hubGroupId: 'hub_test',
    );
    const child = ChannelModel(
      id: 'hub_test_b',
      name: 'Test Hub Beta',
      category: 'Entertainment',
      country: 'India',
      streamUrl: 'https://x.test/hub/b/1.m3u8',
      hubGroupId: 'hub_test',
    );
    final related = ChannelHubProcessor.relatedForChannel(hub, [hub, child]);
    expect(related.length, 1);
    expect(related.first.id, child.id);
  });
}
