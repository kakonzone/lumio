import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/models/model.dart';
import 'package:lumio_tv/provider/app_provider.dart';
import 'package:lumio_tv/provider/user_state_provider.dart';

void main() {
  test('playerRelatedChannels uses GITUN list not main catalog', () {
    final prov = AppProvider(UserStateProvider());
    prov.setGitunChannels([
      const ChannelModel(
        id: 'g1',
        name: 'T Sports',
        category: 'GITUN',
        country: 'BD',
        streamUrl: 'https://a.m3u8',
      ),
      const ChannelModel(
        id: 'g2',
        name: 'Willow HD',
        category: 'GITUN',
        country: 'US',
        streamUrl: 'https://b.m3u8',
      ),
    ]);

    final related = prov.playerRelatedChannels(
      currentTitle: 'T Sports',
      currentUrl: 'https://a.m3u8',
      relatedCategory: 'GITUN',
    );

    expect(related.length, 1);
    expect(related.first.name, 'Willow HD');
    expect(
      AppProvider.relatedSectionLabel('GITUN'),
      'MORE GITUN CHANNELS',
    );
  });
}
