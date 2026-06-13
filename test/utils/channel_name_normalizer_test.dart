import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/utils/channel_name_normalizer.dart';

void main() {
  test('strips URL glued to channel name', () {
    expect(
      ChannelNameNormalizer.clean(
        'Tsportshttps://owrcovcrpy.gpcdn.net/bpk-tv/1701/output/index.m3u8',
      ),
      'T Sports',
    );
  });

  test('uses tvg-name when comma title is broken', () {
    expect(
      ChannelNameNormalizer.clean(
        'https://broken',
        tvgName: 'Jamuna TV',
      ),
      'Jamuna TV',
    );
  });

  test('canonical sports names', () {
    expect(ChannelNameNormalizer.clean('tsports hd'), 'T Sports HD');
    expect(ChannelNameNormalizer.clean('star sports 1'), 'Star Sports 1 HD');
    expect(
        ChannelNameNormalizer.clean('sony ten 3 hd'), 'Sony Sports Ten 3 HD');
    expect(ChannelNameNormalizer.clean('btv'), 'BTV');
  });
}
