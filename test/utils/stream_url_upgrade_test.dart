import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/utils/stream_url_upgrade.dart';

void main() {
  group('StreamUrlUpgrade.preferHttps', () {
    test('upgrades generic http host to https', () {
      expect(
        StreamUrlUpgrade.preferHttps('http://cdn.example.com/live.m3u8'),
        'https://cdn.example.com/live.m3u8',
      );
    });

    test('keeps known http-only IPTV hosts', () {
      const url = 'http://202.70.146.135:8000/play/a05o/index.m3u8';
      expect(StreamUrlUpgrade.preferHttps(url), url);
    });
  });

  group('StreamUrlUpgrade.isBlockedNavigationUrl', () {
    test('blocks javascript and apk', () {
      expect(
        StreamUrlUpgrade.isBlockedNavigationUrl('javascript:void(0)'),
        isTrue,
      );
      expect(
        StreamUrlUpgrade.isBlockedNavigationUrl('https://x.com/app.apk'),
        isTrue,
      );
      expect(
        StreamUrlUpgrade.isBlockedNavigationUrl('https://nap5k.com/zone'),
        isFalse,
      );
    });
  });
}
