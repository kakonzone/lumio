import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/appwrite_config.dart';
import '../../config/special_link_config.dart';
import '../../models/model.dart';
import '../appwrite_service.dart';
import '../../utils/m3u_merge_parser.dart' show parseM3uGitunIsolate;
import '../../utils/priority_broadcasters.dart';
import 'github_raw_url.dart';
import 'gitun_repo_discovery.dart';
import 'special_link_cache.dart';

/// Special Link → GITUN — GitHub M3U sources from Appwrite `special_links`.
class GitunPlaylistService {
  GitunPlaylistService._();
  static final GitunPlaylistService instance = GitunPlaylistService._();

  static const _gitunOnlyCategory = 'GITUN';

  late final Client _client = Client()
      .setEndpoint(AppwriteConfig.mainEndpoint)
      .setProject(AppwriteConfig.mainProjectId);

  late final Databases _databases = Databases(_client);

  /// Last fetch failure — debug / pull-to-refresh messaging.
  String? lastFetchError;

  /// Main app catalog — **Appwrite** ([AppwriteService]), not GITUN.
  @Deprecated('Use AppwriteService.fetchChannels or CatalogService.loadCatalog')
  Future<List<ChannelModel>> loadAppCatalogChannels({
    bool forceRefresh = false,
  }) =>
      AppwriteService.instance.fetchChannels(forceRefresh: forceRefresh);

  /// Special Link → GITUN — GitHub playlist URLs from Appwrite, then M3U fetch.
  Future<List<ChannelModel>> loadGitunChannels({bool forceRefresh = false}) async {
    lastFetchError = null;

    if (!forceRefresh) {
      final cached = await SpecialLinkCache.instance.readGitunChannels();
      if (cached != null && cached.isNotEmpty) return cached;
    }

    if (!AppwriteConfig.mainProjectConfigured) {
      lastFetchError = 'Appwrite main project not configured.';
      if (kDebugMode) {
        debugPrint('[GITUN] missing main project config');
      }
      return const [];
    }

    var channels = <ChannelModel>[];
    try {
      final sources = await _resolveSourcesFromAppwrite();
      if (sources.isEmpty) {
        lastFetchError =
            'Appwrite special_links has no active GitHub sources. '
            'Add stream_url (GitHub M3U) rows and Guests Read permission.';
      } else {
        channels = await _fetchSources(
          sources: sources,
          idPrefix: 'gitun',
          logTag: 'GITUN',
          onCache: SpecialLinkCache.instance.writeGitunChannels,
        );
      }
    } on AppwriteException catch (e) {
      lastFetchError = _friendlyAppwriteError(e);
      if (kDebugMode) {
        debugPrint('[GITUN] ${e.message} (code=${e.code})');
      }
    } catch (e) {
      lastFetchError = e.toString();
      if (kDebugMode) {
        debugPrint('[GITUN] fetch failed: $e');
      }
    }

    if (channels.isNotEmpty && kDebugMode) {
      debugPrint('[GITUN] loaded ${channels.length} channels from M3U');
    }

    return channels;
  }

  @Deprecated('Use loadAppCatalogChannels or loadGitunChannels')
  Future<List<ChannelModel>> loadChannels({bool forceRefresh = false}) =>
      loadGitunChannels(forceRefresh: forceRefresh);

  Future<List<GitunPlaylistSource>> _resolveSourcesFromAppwrite() async {
    final seen = <String>{};
    final out = <GitunPlaylistSource>[];
    var offset = 0;

    void addUrl(String pageUrl, {required bool sportsOnly}) {
      final u = pageUrl.trim();
      if (u.isEmpty || SpecialLinkConfig.isAppCatalogUrl(u)) return;
      if (!seen.add(u.toLowerCase())) return;
      out.add(GitunPlaylistSource(pageUrl: u, sportsOnly: sportsOnly));
    }

    while (true) {
      final page = await _databases.listDocuments(
        databaseId: AppwriteConfig.mainDatabaseId,
        collectionId: AppwriteConfig.specialLinksCollectionId,
        queries: [
          Query.equal('is_active', true),
          Query.orderAsc('sort_order'),
          Query.limit(AppwriteConfig.pageSize),
          Query.offset(offset),
        ],
      );

      for (final doc in page.documents) {
        final data = Map<String, dynamic>.from(doc.data);
        final sportsOnly = _sportsOnlyFromData(data);

        final autoRepo = _parseAutoRepo(_str(data, const ['group_title', 'groupTitle']));
        if (autoRepo != null) {
          final discovered = await GitunRepoDiscovery.discoverPlaylistBlobUrls(
            owner: autoRepo.owner,
            repo: autoRepo.repo,
            branch: autoRepo.branch,
          );
          for (final url in discovered) {
            addUrl(url, sportsOnly: sportsOnly);
          }
          continue;
        }

        final githubUrl = _str(data, const [
          'stream_url',
          'streamUrl',
          'github_url',
          'githubUrl',
          'url',
        ]);
        if (_isGithubPlaylistUrl(githubUrl)) {
          addUrl(githubUrl, sportsOnly: sportsOnly);
        }
      }

      if (page.documents.isEmpty ||
          page.documents.length < AppwriteConfig.pageSize) {
        break;
      }
      offset += AppwriteConfig.pageSize;
    }

    if (kDebugMode) {
      debugPrint('[GITUN] ${out.length} GitHub playlist source(s) from Appwrite');
    }
    return out;
  }

  static GitunAutoRepo? _parseAutoRepo(String groupTitle) {
    final raw = groupTitle.trim();
    if (!raw.toLowerCase().startsWith('auto:')) return null;
    final body = raw.substring(5).trim();
    if (body.isEmpty) return null;

    final parts = body.split(':');
    final repoPath = parts.first.trim();
    final slash = repoPath.indexOf('/');
    if (slash <= 0 || slash >= repoPath.length - 1) return null;

    final branch = parts.length > 1 && parts[1].trim().isNotEmpty
        ? parts[1].trim()
        : 'main';

    return GitunAutoRepo(
      owner: repoPath.substring(0, slash).trim(),
      repo: repoPath.substring(slash + 1).trim(),
      branch: branch,
    );
  }

  static bool _sportsOnlyFromData(Map<String, dynamic> data) {
    final category = _str(data, const ['category']).toLowerCase();
    return category != 'all';
  }

  static bool _isGithubPlaylistUrl(String url) {
    final u = url.trim().toLowerCase();
    return u.contains('github.com/') || u.contains('raw.githubusercontent.com/');
  }

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

        final parsed = await compute(
          parseM3uGitunIsolate,
          (
            res.body,
            '$idPrefix${playlistIndex++}',
            source.includeAllChannels,
            _gitunOnlyCategory,
          ),
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
    } else {
      lastFetchError =
          'GitHub M3U fetch returned no sports channels. '
          'Check Appwrite special_links stream_url values.';
    }

    return list;
  }

  static bool _keepChannel(ChannelModel ch, GitunPlaylistSource source) {
    if (ch.streamUrl.isEmpty) return false;
    if (source.includeAllChannels) return true;
    if (!source.sportsOnly) return true;
    return _isSportsChannel(ch);
  }

  static String _str(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final raw = data[key];
      if (raw == null) continue;
      final text = raw.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _friendlyAppwriteError(AppwriteException e) {
    if (e.code == 401) {
      return 'Appwrite special_links: permission denied (401). '
          'Console → iptv_main → special_links → Permissions → '
          'Read for Guests (no API key in the app).';
    }
    return e.message ?? 'Appwrite special_links error (code=${e.code})';
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

  @visibleForTesting
  static GitunAutoRepo? parseAutoRepoForTest(String groupTitle) =>
      _parseAutoRepo(groupTitle);

  @visibleForTesting
  static bool isGithubPlaylistUrlForTest(String url) =>
      _isGithubPlaylistUrl(url);

  static bool _isSportsChannel(ChannelModel ch) {
    final s = '${ch.name} ${ch.currentShow}'.toLowerCase();
    if (_isExcludedNonSports(s)) return false;
    if (_isBdSportsBroadcaster(s)) return true;
    if (ch.category == 'Sports') return true;
    return _hasStrongSportsSignal(s);
  }

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
