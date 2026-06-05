import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/special_link_config.dart';
import '../../models/model.dart';
import '../appwrite_service.dart';
import '../../utils/m3u_merge_parser.dart';
import '../../utils/priority_broadcasters.dart';
import 'github_raw_url.dart';
import 'gitun_repo_discovery.dart';
import 'special_link_cache.dart';

/// Fetches M3U playlists from GitHub (owner catalog vs GITUN third-party).
class GitunPlaylistService {
  GitunPlaylistService._();
  static final GitunPlaylistService instance = GitunPlaylistService._();

  static const _gitunOnlyCategory = 'GITUN';

  /// Main app catalog — **Appwrite** ([AppwriteService]), not GitHub.
  @Deprecated('Use AppwriteService.fetchChannels or CatalogService.loadCatalog')
  Future<List<ChannelModel>> loadAppCatalogChannels({
    bool forceRefresh = false,
  }) =>
      AppwriteService.instance.fetchChannels(forceRefresh: forceRefresh);

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
      logTag: 'GITUN',
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
    required String logTag,
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
            debugPrint('[$logTag] skip $rawUrl http=${res.statusCode}');
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
            '[$logTag] $rawUrl parsed=$parsedCount kept=$keptCount '
            'merged=${merged.length}',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[$logTag] fetch failed $rawUrl: $e');
        }
      }
    }

    final list = PriorityBroadcasters.sort(merged.values.toList());

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

  static String _mergeKey(String name) {
    var s = name.toLowerCase().replaceAll(RegExp(r'[+_|]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s
        .replaceAll(
          RegExp(r'\b(hd|fhd|sd|4k|uhd|hevc|live)\b'),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final alias = _canonicalMergeAlias(s);
    return alias ?? s;
  }

  /// Same broadcaster across GitHub playlists → one row, multi-link in player.
  static String? _canonicalMergeAlias(String s) {
    if (RegExp(r't\s*sports?|tsports').hasMatch(s)) return 't sports';
    if (RegExp(r'^btv\b|bangladesh television').hasMatch(s)) return 'btv';
    if (s.contains('gazi')) return 'gazi tv';
    if (s.contains('nagorik') || s.contains('nagrik')) return 'nagorik tv';
    if (s.contains('channel 9') || s == 'channel9') return 'channel 9';
    if (s.contains('willow') && !RegExp(r'willow\s*\d').hasMatch(s)) {
      return 'willow';
    }
    if (s.contains('fifa')) return 'fifa';
    if (RegExp(r'bein\s*sport|bein\s*\d|beinsport').hasMatch(s)) {
      return s.replaceAll(RegExp(r'\s+'), ' ');
    }
    return null;
  }

  @visibleForTesting
  static bool isSportsChannelForTest(ChannelModel ch) => _isSportsChannel(ch);

  @visibleForTesting
  static String mergeKeyForTest(String name) => _mergeKey(name);

  /// All GITUN rows are tagged category GITUN before filtering — never use that alone.
  static bool _isSportsChannel(ChannelModel ch) {
    final s = '${ch.name} ${ch.currentShow}'.toLowerCase();
    if (_isExcludedNonSports(s)) return false;
    if (_isBdSportsBroadcaster(s)) return true;
    if (ch.category == 'Sports') return true;
    return _hasStrongSportsSignal(s);
  }

  /// News, music, Hindi entertainment, movies — drop unless name is clearly sports.
  static bool _isExcludedNonSports(String s) {
    if (_hasStrongSportsSignal(s)) return false;

    const exclude = [
      ' news',
      'news ',
      'breaking',
      'somoy',
      'jamuna',
      'independent tv',
      'channel 24',
      'channel i',
      'channel 71',
      'atn news',
      'rtv',
      'dbc',
      'boishakhi',
      'ekattor',
      'nrb',
      'jago news',
      'bangla vision',
      'cnn',
      'bbc',
      'al jazeera',
      'wion',
      'republic',
      'aaj tak',
      'abp',
      'ndtv',
      'zee news',
      'music',
      '9xm',
      '9x jalwa',
      'mtv',
      'vh1',
      'b4u music',
      'song',
      'hits',
      'radio',
      'bollywood',
      'hindi',
      'zee tv',
      'zee bangla',
      'zee cinema',
      'zee anmol',
      'colors bangla',
      'colors hindi',
      'colors tv',
      'star plus',
      'star jalsha',
      'star gold',
      'star bharat',
      'sony tv',
      'sony sab',
      'sony pal',
      'sony max',
      'sab tv',
      '&tv',
      'and tv',
      'rishtey',
      'bindass',
      'nick ',
      'nickelodeon',
      'cartoon',
      'pogo',
      'disney',
      'baby tv',
      'discovery',
      'nat geo',
      'national geographic',
      'history',
      'animal planet',
      'food',
      'cooking',
      'religious',
      'quran',
      'madani',
      'islamic',
      'peace tv',
      'maidan',
      'movie',
      'cinema',
      'film',
      'drama',
      'entertainment',
      'serial',
      'geet',
      'rang',
      'dhoom',
    ];
    if (exclude.any(s.contains)) return true;

    if (s.contains('gazi') && !s.contains('sport')) return true;
    if ((s.contains('nagorik') || s.contains('nagrik')) && !s.contains('sport')) {
      return true;
    }
    if (RegExp(r'\bbtv\b').hasMatch(s) && s.contains('news')) return true;

    return false;
  }

  static bool _hasStrongSportsSignal(String s) {
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
      'formula 1',
      'formula one',
      'motogp',
      'tennis',
      'golf',
      ' vs ',
      'willow',
      'fifa',
      'espn',
      'fox sports',
      'fox sport',
      'star sports',
      'sony sports',
      'sony ten',
      'eurosport',
      'sky sports',
      'sky sport',
      'tnt sports',
      'tnt sport',
      'tsports',
      't sports',
      'ptv sports',
      'ptv sport',
      'bein sport',
      'bein sports',
      'beinsport',
      'dazn',
      'fancode',
      'supersport',
      'super sport',
      'premier league',
      'epl',
      'ucl',
      'champions league',
      'laliga',
      'bundesliga',
      'ipl',
      'bpl',
      'psl',
      'cpl',
      'mls',
      'astro supersport',
      'sky cricket',
      'roxi sports',
      'streameast',
      'mlbwebcast',
    ];
    return keys.any(s.contains);
  }

  /// BD channels commonly used for live sports (not general news feeds).
  static bool _isBdSportsBroadcaster(String s) {
    if (RegExp(r't\s*sports?|tsports').hasMatch(s)) return true;
    if (RegExp(r'\bbtv\b|bangladesh television').hasMatch(s)) {
      return !s.contains('news');
    }
    if (s.contains('channel 9') || s.contains('channel9')) {
      return !s.contains('news') && !s.contains('music');
    }
    if (s.contains('gazi') && s.contains('sport')) return true;
    if ((s.contains('nagorik') || s.contains('nagrik')) && s.contains('sport')) {
      return true;
    }
    return false;
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
