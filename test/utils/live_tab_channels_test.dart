import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/models/model.dart';
import 'package:lumio_tv/utils/live_tab_channels.dart';

void main() {
  test('filters Sports and Movies m3u8 only', () {
    final pool = LiveTabChannels.filter([
      const ChannelModel(
        id: '1',
        name: 'Star Sports',
        category: 'Sports',
        country: '',
        streamUrl: 'https://x/live.m3u8',
      ),
      const ChannelModel(
        id: '2',
        name: 'HBO',
        category: 'Movies',
        country: '',
        streamUrl: 'https://y/movie.m3u8',
      ),
      const ChannelModel(
        id: '3',
        name: 'News',
        category: 'News',
        country: '',
        streamUrl: 'https://z/news.m3u8',
      ),
      const ChannelModel(
        id: '4',
        name: 'TS',
        category: 'Sports',
        country: '',
        streamUrl: 'https://mp4/not-m3u8',
      ),
    ]);
    expect(pool.length, 2);
    expect(pool.any((c) => c.category == 'Sports'), isTrue);
    expect(pool.any((c) => c.category == 'Movies'), isTrue);
  });
}
