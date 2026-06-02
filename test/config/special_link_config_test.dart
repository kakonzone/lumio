import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/config/special_link_config.dart';

void main() {
  test('app catalog URL is not listed in GITUN sources', () {
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

  test('isAppCatalogUrl detects kakonzone playlist', () {
    expect(
      SpecialLinkConfig.isAppCatalogUrl(
        SpecialLinkConfig.appCatalogPlaylistUrl,
      ),
      isTrue,
    );
    expect(
      SpecialLinkConfig.isAppCatalogUrl(
        'https://github.com/kakonzone/allchannelking.m3u8/blob/main/foo.m3u8',
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
