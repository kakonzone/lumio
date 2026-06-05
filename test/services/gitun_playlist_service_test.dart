import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/config/special_link_config.dart';
import 'package:lumio_tv/models/model.dart';
import 'package:lumio_tv/services/special_link/gitun_playlist_service.dart';

void main() {
  const base = ChannelModel(
    id: 'x',
    name: 'x',
    category: 'GITUN',
    country: 'International',
    streamUrl: 'https://example.com/s.m3u8',
  );

  test('PiratesTv playlist is registered in GITUN sources', () {
    final urls = SpecialLinkConfig.gitunPlaylistSources
        .map((s) => s.pageUrl.toLowerCase())
        .toList();
    expect(
      urls.any((u) => u.contains('functionerror/piratestv')),
      isTrue,
    );
  });

  test('GITUN category alone does not pass sports filter', () {
    expect(
      GitunPlaylistService.isSportsChannelForTest(
        base.copyWith(name: 'Random Entertainment'),
      ),
      isFalse,
    );
  });

  test('sports filter keeps sports and drops news hindi music', () {
    expect(
      GitunPlaylistService.isSportsChannelForTest(
        base.copyWith(name: 'BTV'),
      ),
      isTrue,
    );
    expect(
      GitunPlaylistService.isSportsChannelForTest(
        base.copyWith(name: 'T Sports HD'),
      ),
      isTrue,
    );
    expect(
      GitunPlaylistService.isSportsChannelForTest(
        base.copyWith(name: 'Star Sports 1'),
      ),
      isTrue,
    );
    expect(
      GitunPlaylistService.isSportsChannelForTest(
        base.copyWith(name: 'Willow HD'),
      ),
      isTrue,
    );
    expect(
      GitunPlaylistService.isSportsChannelForTest(
        base.copyWith(name: 'Jamuna TV'),
      ),
      isFalse,
    );
    expect(
      GitunPlaylistService.isSportsChannelForTest(
        base.copyWith(name: 'Zee TV'),
      ),
      isFalse,
    );
    expect(
      GitunPlaylistService.isSportsChannelForTest(
        base.copyWith(name: 'Colors Bangla'),
      ),
      isFalse,
    );
    expect(
      GitunPlaylistService.isSportsChannelForTest(
        base.copyWith(name: '9XM'),
      ),
      isFalse,
    );
    expect(
      GitunPlaylistService.isSportsChannelForTest(
        base.copyWith(name: 'Somoy TV'),
      ),
      isFalse,
    );
    expect(
      GitunPlaylistService.isSportsChannelForTest(
        base.copyWith(name: 'Gazi TV'),
      ),
      isFalse,
    );
    expect(
      GitunPlaylistService.isSportsChannelForTest(
        base.copyWith(name: 'Nagorik TV'),
      ),
      isFalse,
    );
    expect(
      GitunPlaylistService.isSportsChannelForTest(
        base.copyWith(name: 'Gazi Sports'),
      ),
      isTrue,
    );
  });

  test('merge key unifies T Sports variants for multilink', () {
    expect(
      GitunPlaylistService.mergeKeyForTest('T Sports HD'),
      GitunPlaylistService.mergeKeyForTest('Tsports'),
    );
    expect(
      GitunPlaylistService.mergeKeyForTest('BTV HD'),
      GitunPlaylistService.mergeKeyForTest('BTV'),
    );
  });
}
