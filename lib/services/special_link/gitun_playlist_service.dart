import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:dart_appwrite/models.dart' as aw_models;
import 'package:flutter/foundation.dart';

import '../../config/appwrite_config.dart';
import '../../models/model.dart';
import '../appwrite_service.dart';
import '../../utils/priority_broadcasters.dart';
import 'special_link_cache.dart';

/// Special Link → GITUN — Appwrite `special_links` collection (main project).
class GitunPlaylistService {
  GitunPlaylistService._();
  static final GitunPlaylistService instance = GitunPlaylistService._();

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

  /// Special Link → GITUN — active rows from Appwrite, ordered by sort_order.
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
      channels = await _fetchSpecialLinkDocuments();
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

    if (channels.isNotEmpty) {
      await SpecialLinkCache.instance.writeGitunChannels(channels);
      if (kDebugMode) {
        debugPrint('[GITUN] loaded ${channels.length} special links');
      }
    }

    return channels;
  }

  @Deprecated('Use loadAppCatalogChannels or loadGitunChannels')
  Future<List<ChannelModel>> loadChannels({bool forceRefresh = false}) =>
      loadGitunChannels(forceRefresh: forceRefresh);

  Future<List<ChannelModel>> _fetchSpecialLinkDocuments() async {
    final out = <ChannelModel>[];
    var offset = 0;

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
        final ch = _fromDocument(doc);
        if (ch != null) out.add(ch);
      }

      if (page.documents.isEmpty ||
          page.documents.length < AppwriteConfig.pageSize) {
        break;
      }
      offset += AppwriteConfig.pageSize;
    }

    if (out.isEmpty) {
      lastFetchError =
          'Appwrite special_links returned no active rows. '
          'Check is_active, stream_url, and Guests Read permission.';
    }

    return PriorityBroadcasters.sort(out);
  }

  static ChannelModel? _fromDocument(aw_models.Document doc) {
    final data = Map<String, dynamic>.from(doc.data);
    final name = _str(data, const ['name', 'title', 'channel_name']);
    final streamUrl = _str(data, const ['stream_url', 'streamUrl', 'url']);
    if (name.isEmpty || streamUrl.isEmpty) return null;

    final logo = _str(data, const ['logo_url', 'logoUrl', 'logo']);
    final group = _str(data, const ['group_title', 'groupTitle', 'group']);
    final category = _str(data, const ['category']).isEmpty
        ? 'Sports'
        : _str(data, const ['category']);

    return ChannelModel(
      id: doc.$id.isNotEmpty ? doc.$id : 'gitun_${name.hashCode}',
      name: name,
      category: category,
      country: 'International',
      streamUrl: streamUrl,
      logoUrl: logo,
      isLive: true,
      currentShow: group,
    );
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
          'Console → database-iptv_main → special_links → Permissions → '
          'Read for Guests (no API key in the app).';
    }
    return e.message ?? 'Appwrite special_links error (code=${e.code})';
  }

  // ── Legacy test helpers (sports filter no longer applied at fetch time) ───

  @visibleForTesting
  static bool isSportsChannelForTest(ChannelModel ch) =>
      _isSportsChannel(ch);

  @visibleForTesting
  static String mergeKeyForTest(String name) => _mergeKey(name);

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
}
