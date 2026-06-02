import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/config/channel_categories.dart';
import 'package:lumio_tv/models/model.dart';

void main() {
  test('M3U group Sports and Bangladesh map directly', () {
    expect(
      ChannelCategoryRegistry.fromGroupTitle('Sports', 'Any'),
      'Sports',
    );
    expect(
      ChannelCategoryRegistry.fromGroupTitle('Bangladesh', 'BTV'),
      'Bangladesh',
    );
  });

  test('Live TV group refines by channel name', () {
    expect(
      ChannelCategoryRegistry.fromGroupTitle('Live TV', 'Jagonews24.Stream'),
      'News',
    );
    expect(
      ChannelCategoryRegistry.fromGroupTitle('Live TV', 'Discovery Hd'),
      'Entertainment',
    );
  });

  test('tiles only include categories with channels', () {
    final channels = [
      const ChannelModel(
        id: '1',
        name: 'Star Sports 1',
        category: 'Sports',
        country: 'India',
        streamUrl: 'https://x.m3u8',
      ),
      const ChannelModel(
        id: '2',
        name: 'Random',
        category: 'Live TV',
        country: 'India',
        streamUrl: 'https://y.m3u8',
      ),
    ];
    final tiles = ChannelCategoryRegistry.tilesForChannels(channels);
    final ids = tiles.map((t) => t['cat']).toSet();
    expect(ids, contains('Sports'));
    expect(ids, contains('Live TV'));
    expect(ids, isNot(contains('Movies')));
  });

  test('home tiles are fixed set without Browse All extras', () {
    final channels = [
      const ChannelModel(
        id: '1',
        name: 'Star Sports 1',
        category: 'Sports',
        country: 'India',
        streamUrl: 'https://x.m3u8',
      ),
      const ChannelModel(
        id: '2',
        name: 'Zee News',
        category: 'News',
        country: 'India',
        streamUrl: 'https://y.m3u8',
      ),
    ];
    final tiles = ChannelCategoryRegistry.homeTilesForChannels(channels);
    final ids = tiles.map((t) => t['cat']).toList();
    expect(
      ids,
      [
        'Sports',
        'Bangladesh',
        'Entertainment',
        'Movies',
        'Kids',
        'Live TV',
        ChannelCategoryRegistry.specialLinkId,
      ],
    );
    expect(ids, isNot(contains('News')));
    expect(tiles.firstWhere((t) => t['cat'] == 'Kids')['label'], 'Cartoon');
  });
}
