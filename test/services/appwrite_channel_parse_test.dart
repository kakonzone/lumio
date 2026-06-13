import 'package:dart_appwrite/models.dart' as aw_models;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/models/model.dart';
import 'package:lumio_tv/services/appwrite_channel_mapper.dart';
import 'package:lumio_tv/utils/channel_playback_links.dart';

void main() {
  test('parses Appwrite document into ChannelModel with alternates', () {
    final doc = aw_models.Document(
      $id: 'ch1',
      $sequence: '1',
      $collectionId: 'channels',
      $databaseId: 'iptv_main',
      $createdAt: '',
      $updatedAt: '',
      $permissions: const [],
      data: {
        'name': 'T Sports HD',
        'category': 'Sports',
        'country': 'Bangladesh',
        'streamUrl': 'https://a.test/1.m3u8',
        'urls': ['https://a.test/2.m3u8'],
      },
    );

    final ch = AppwriteChannelMapper.fromDocument(doc);
    expect(ch, isNotNull);
    expect(ch!.name, 'T Sports HD');
    expect(ch.userStreamLinks.length, 2);
  });

  test('merges Appwrite rows with same mergeKey into one multi-link channel',
      () {
    final a = AppwriteChannelMapper.fromDocument(_doc(
      id: 'a',
      name: 'T Sports HD',
      url: 'https://a.test/1.m3u8',
      mergeKey: 't-sports',
    ))!;
    final b = AppwriteChannelMapper.fromDocument(_doc(
      id: 'b',
      name: 'T Sports FHD',
      url: 'https://a.test/2.m3u8',
      mergeKey: 't-sports',
    ))!;

    final merged = AppwriteChannelMapper.mergeRows(a, b);
    expect(merged.userStreamLinks.length, 2);

    final bar = ChannelPlaybackLinks.resolve(merged, [merged]);
    expect(bar.length, 2);
  });

  test('player link bar collects streamUrl2 on one document', () {
    final ch = AppwriteChannelMapper.fromDocument(_doc(
      id: 'c',
      name: 'Sony Ten 1',
      url: 'https://a.test/1.m3u8',
      extra: {'streamUrl2': 'https://a.test/2.m3u8'},
    ))!;

    expect(ch.userStreamLinks.length, 2);
    expect(
      ChannelPlaybackLinks.resolve(ch, [ch]).map((l) => l.url),
      contains('https://a.test/2.m3u8'),
    );
  });
}

aw_models.Document _doc({
  required String id,
  required String name,
  required String url,
  String? mergeKey,
  Map<String, dynamic>? extra,
}) {
  return aw_models.Document(
    $id: id,
    $sequence: '1',
    $collectionId: 'channels',
    $databaseId: 'iptv_main',
    $createdAt: '',
    $updatedAt: '',
    $permissions: const [],
    data: {
      'name': name,
      'category': 'Sports',
      'streamUrl': url,
      if (mergeKey != null) 'mergeKey': mergeKey,
      ...?extra,
    },
  );
}
