import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/services/special_link/gitun_repo_discovery.dart';

void main() {
  test('discoverPlaylistBlobUrls finds multiple m3u8 in Sports.M3U8', () async {
    final urls = await GitunRepoDiscovery.discoverPlaylistBlobUrls(
      owner: 'yIsus-mEx',
      repo: 'Sports.M3U8',
    );
    expect(urls.length, greaterThan(3));
    expect(
      urls.any((u) => u.contains('TVTVHD.m3u8')),
      isTrue,
    );
    expect(
      urls.any((u) => u.contains('.01.06.2026.')),
      isFalse,
    );
  }, skip: !const bool.fromEnvironment('RUN_NETWORK_TESTS'));
}
