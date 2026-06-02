import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/special_link_config.dart';
import '../../models/model.dart';
import '../../utils/m3u_merge_parser.dart';
import 'github_raw_url.dart';
import 'gitun_repo_discovery.dart';
import 'special_link_cache.dart';

/// Fetches M3U playlists from GitHub (owner catalog vs GITUN third-party).
class GitunPlaylistService {
  GitunPlaylistService._();
  static final GitunPlaylistService instance = GitunPlaylistService._();

  static const _gitunOnlyCategory = 'GITUN';

  /// Main app catalog — **only** [SpecialLinkConfig.appCatalogPlaylistUrl].
  Future<List<ChannelModel>> loadAppCatalogChannels({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await SpecialLinkCache.instance.readAppCatalogChannels();
      if (cached != null && cached.isNotEmpty) return cached;
    }

    const source = GitunPlaylistSource(
      pageUrl: SpecialLinkConfig.appCatalogPlaylistUrl,
      includeAllChannels: true,
    );

    final list = await _fetchSources(
      sources: const [source],
      idPrefix: 'lumio',
      onCache: SpecialLinkCache.instance.writeAppCatalogChannels,
    );
    return list;
  }

  /// Special Link → GITUN — third-party GitHub playlists only (not owner catalog).
  Future<List<ChannelModel>> loadGitunChannels({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await SpecialLinkCache.instance.readGitunChannels();
      if (cached != null && cached.isNotEmpty) return cached;
    }

    final sources = await _resolveGitunSources();

    final list = await _fetchSources(
      sources: sources,
      idPrefix: 'gitun',
      onCache: SpecialLinkCache.instance.writeGitunChannels,
    );
    return list;
  }

  /// Manual sources + auto-discovered M3U files from [SpecialLinkConfig.gitunAutoDiscoverRepos].
  Future<List<GitunPlaylistSource>> _resolveGitunSources() async {
    final seen = <String>{};
    final out = <GitunPlaylistSource>[];

    void addUrl(String pageUrl, {bool sportsOnly = true}) {
      final u = pageUrl.trim();
      if (u.isEmpty || SpecialLinkConfig.isAppCatalogUrl(u)) return;
      if (!seen.add(u.toLowerCase())) return;
      out.add(GitunPlaylistSource(pageUrl: u, sportsOnly: sportsOnly));
    }

    for (final repo in SpecialLinkConfig.gitunAutoDiscoverRepos) {
      final discovered = await GitunRepoDiscovery.discoverPlaylistBlobUrls(
        owner: repo.owner,
        repo: repo.repo,
        branch: repo.branch,
      );
      for (final url in discovered) {
        addUrl(url, sportsOnly: true);
      }
    }

    for (final source in SpecialLinkConfig.gitunPlaylistSources) {
      addUrl(source.pageUrl, sportsOnly: source.sportsOnly);
    }

    if (kDebugMode) {
      debugPrint('[GITUN] loading ${out.length} third-party playlist(s)');
    }
    return out;
  }

  @Deprecated('Use loadAppCatalogChannels or loadGitunChannels')
  Future<List<ChannelModel>> loadChannels({bool forceRefresh = false}) =>
      loadGitunChannels(forceRefresh: forceRefresh);

  Future<List<ChannelModel>> _fetchSources({
    required List<GitunPlaylistSource> sources,
    required String idPrefix,
    required Future<void> Function(List<ChannelModel>) onCache,
  }) async {
    if (sources.isEmpty) return const [];

    final merged = <String, ChannelModel>{};
    var playlistIndex = 0;

    for (final source in sources) {
      final rawUrl = GithubRawUrl.resolve(source.pageUrl);
      var parsedCount = 0;
      var keptCount = 0;

      try {
        final res = await http
            .get(
              Uri.parse(rawUrl),
              headers: const {
                'User-Agent': 'Mozilla/5.0 (compatible; LumioTV/1.0)',
                'Accept': '*/*',
              },
            )
            .timeout(const Duration(seconds: 25));

        if (res.statusCode != 200) {
          if (kDebugMode) {
            debugPrint('[GITUN] skip $rawUrl http=${res.statusCode}');
          }
          continue;
        }

        final parsed = M3uMergeParser.parse(
          res.body,
          idPrefix: '$idPrefix${playlistIndex++}',
          mapCategory: (group, name) => source.includeAllChannels
              ? M3uMergeParser.categoryForGroup(group, name)
              : _gitunOnlyCategory,
          mapCountry: (_, __) => 'International',
        );
        parsedCount = parsed.length;

        for (final ch in parsed) {
          if (!_keepChannel(ch, source)) continue;
          keptCount++;

          final display = source.includeAllChannels
              ? ch.copyWith(isLive: true)
              : ch.copyWith(category: _gitunOnlyCategory, isLive: true);
          final key = _mergeKey(display.name);
          final existing = merged[key];
          if (existing == null) {
            merged[key] = display;
          } else {
            merged[key] = _mergeChannels(existing, display);
          }
        }

        if (kDebugMode) {
          debugPrint(
            '[GITUN] $rawUrl parsed=$parsedCount kept=$keptCount '
            'merged=${merged.length}',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[GITUN] fetch failed $rawUrl: $e');
        }
      }
    }

    final list = merged.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (list.isNotEmpty) {
      await onCache(list);
    }
    return list;
  }

  /// GITUN: sports-only unless [GitunPlaylistSource.sportsOnly] is false.
  static bool _keepChannel(ChannelModel ch, GitunPlaylistSource source) {
    if (ch.streamUrl.isEmpty) return false;
    if (source.includeAllChannels) return true;
    if (!source.sportsOnly) return true;
    return _isSportsChannel(ch);
  }

  static String _mergeKey(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static bool _isSportsChannel(ChannelModel ch) {
    if (ch.category == 'Sports' || ch.category == 'GITUN') return true;
    final s = '${ch.name} ${ch.currentShow}'.toLowerCase();
    const keys = [
      'sport',
      'cricket',
      'football',
      'soccer',
      'rugby',
      'hockey',
      'nhl',
      'mlb',
      'nba',
      'nfl',
      'ncaa',
      'ufc',
      'boxing',
      'wrestling',
      'wwe',
      'f1',
      'formula',
      'motogp',
      'tennis',
      'golf',
      'match',
      ' vs ',
      'live ',
      'stream',
      'strea',
      'willow',
      'espn',
      'fox sport',
      'star sports',
      'sony sports',
      'sony ten',
      'eurosport',
      'sky sport',
      'tnt sport',
      'tsports',
      't sports',
      'ptv sport',
      'bein',
      'dazn',
      'fancode',
      'supersport',
      'premier',
      'epl',
      'ucl',
      'champions',
      'laliga',
      'bundesliga',
      'serie a',
      'ipl',
      'bpl',
      'psl',
      'cpl',
      'mls',
      'roxi',
      'roxie',
      'shark',
      'slapstream',
      'streameast',
      'webcast',
      'mlbwebcast',
    ];
    return keys.any(s.contains);
  }

  static ChannelModel _mergeChannels(ChannelModel a, ChannelModel b) {
    final seen = <String>{};
    final links = <StreamLink>[];

    void addFrom(ChannelModel ch) {
      for (final link in ch.allStreams) {
        if (link.url.isEmpty || seen.contains(link.url)) continue;
        seen.add(link.url);
        links.add(
          StreamLink(
            url: link.url,
            label: 'Link ${links.length + 1}',
            headers: link.headers.isNotEmpty
                ? link.headers
                : (a.headers.isNotEmpty ? a.headers : b.headers),
          ),
        );
      }
    }

    addFrom(a);
    addFrom(b);

    if (links.isEmpty) return a;

    return a.copyWith(
      streamUrl: links.first.url,
      alternateStreams: links.length > 1 ? links.sublist(1) : const [],
      logoUrl: a.logoUrl.isNotEmpty ? a.logoUrl : b.logoUrl,
      headers: links.first.headers,
      isLive: true,
    );
  }
}
