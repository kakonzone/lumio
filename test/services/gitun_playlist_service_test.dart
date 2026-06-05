import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

  test('special_links.json contains PiratesTv GitHub source', () {
    final file = File('data/special_links.json');
    final list = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    final urls = list
        .map((e) => (e as Map<String, dynamic>)['stream_url']?.toString() ?? '')
        .map((u) => u.toLowerCase())
        .toList();
    expect(urls.any((u) => u.contains('functionerror/piratestv')), isTrue);
  });

  test('parses auto-discover repo from group_title', () {
    final repo = GitunPlaylistService.parseAutoRepoForTest(
      'auto:yIsus-mEx/Sports.M3U8:main',
    );
    expect(repo?.owner, 'yIsus-mEx');
    expect(repo?.repo, 'Sports.M3U8');
    expect(repo?.branch, 'main');
  });

  test('detects GitHub playlist URLs', () {
    expect(
      GitunPlaylistService.isGithubPlaylistUrlForTest(
        'https://github.com/yIsus-mEx/Sports.M3U8/blob/main/TVTVHD.m3u8',
      ),
      isTrue,
    );
    expect(
      GitunPlaylistService.isGithubPlaylistUrlForTest(
        'https://stream.example.com/live.m3u8',
      ),
      isFalse,
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
