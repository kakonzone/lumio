import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/config/special_link_config.dart';

void main() {
  test('GITUN sources do not include owner catalog URLs', () {
    for (final source in SpecialLinkConfig.gitunPlaylistSources) {
      expect(
        SpecialLinkConfig.isAppCatalogUrl(source.pageUrl),
        isFalse,
        reason: 'GITUN must not include owner catalog: ${source.pageUrl}',
      );
      expect(source.sportsOnly, isTrue);
      expect(source.includeAllChannels, isFalse);
    }
  });

  test('isAppCatalogUrl detects legacy owner GitHub playlists', () {
    expect(
      SpecialLinkConfig.isAppCatalogUrl(
        'https://github.com/kakon122/my-media-notes/blob/main/foo.m3u8',
      ),
      isTrue,
    );
    expect(
      SpecialLinkConfig.isAppCatalogUrl(
        'https://github.com/yIsus-mEx/Sports.M3U8/blob/main/TVTVHD.m3u8',
      ),
      isFalse,
    );
  });
}
