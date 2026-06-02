import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/services/special_link/github_raw_url.dart';

void main() {
  test('converts github blob URL to raw', () {
    const blob =
        'https://github.com/yIsus-mEx/Sports.M3U8/blob/main/TVTVHD.m3u8';
    expect(
      GithubRawUrl.resolve(blob),
      'https://raw.githubusercontent.com/yIsus-mEx/Sports.M3U8/main/TVTVHD.m3u8',
    );
  });

  test('leaves direct URLs unchanged', () {
    const direct = 'https://iptv-org.github.io/iptv/index.m3u';
    expect(GithubRawUrl.resolve(direct), direct);
  });

  test('kakonzone allchannelking.m3u8 blob URL', () {
    const blob =
        'https://github.com/kakonzone/allchannelking.m3u8/blob/main/allchannelking.m3u8';
    expect(
      GithubRawUrl.resolve(blob),
      'https://raw.githubusercontent.com/kakonzone/allchannelking.m3u8/main/allchannelking.m3u8',
    );
  });
}
