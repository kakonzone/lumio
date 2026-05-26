import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/extra_channels.dart';
import '../data/toffee_channels.dart';
import '../utils/channel_catalog.dart';
import '../models/model.dart';
import '../models/live_event_match.dart';
import '../services/live_events_service.dart';
import '../services/news_service.dart';
import '../services/score_service.dart';
import '../services/stream_health_service.dart';
import '../utils/live_event_sort.dart';
import '../utils/match_grouping.dart';
import '../utils/debug_log.dart';
import '../utils/m3u_merge_parser.dart';
import '../utils/channel_hub_processor.dart';
import '../network/toffee_headers.dart';

class AppProvider extends ChangeNotifier {
  // ── M3U source ────────────────────────────────────────────
  static const String _m3uUrl = 'https://is.gd/B52fXp.m3u';

  // ── Favourites ────────────────────────────────────────────
  static const _favoritesKey = 'lumio_favorite_channel_ids';
  final Set<String> _favoriteIds = {};

  int get favoriteCount => _favoriteIds.length;

  bool isFavorite(String channelId) => _favoriteIds.contains(channelId);

  /// Channel user tapped before first-tap ad; highlighted until they tap again to play.
  String? _pendingChannelTapId;

  String? get pendingChannelTapId => _pendingChannelTapId;

  bool isPendingChannelTap(String channelKey) =>
      channelKey.isNotEmpty && _pendingChannelTapId == channelKey;

  bool isPendingChannelTapChannel(ChannelModel channel) =>
      isPendingChannelTap(
        channel.id.isNotEmpty ? channel.id : channel.name,
      );

  void setPendingChannelTap(String? channelId) {
    if (_pendingChannelTapId == channelId) return;
    _pendingChannelTapId = channelId;
    notifyListeners();
  }

  String? _pendingNewsArticleId;

  bool isPendingNewsArticle(String articleId) =>
      articleId.isNotEmpty && _pendingNewsArticleId == articleId;

  void setPendingNewsArticle(String? articleId) {
    if (_pendingNewsArticleId == articleId) return;
    _pendingNewsArticleId = articleId;
    notifyListeners();
  }

  List<ChannelModel> get favoriteChannels {
    final list = _channels.where((c) => _favoriteIds.contains(c.id)).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<void> loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_favoritesKey) ?? [];
      _favoriteIds
        ..clear()
        ..addAll(ids);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> addFavorite(ChannelModel channel) async {
    if (channel.id.isEmpty) return;
    _favoriteIds.add(channel.id);
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> removeFavorite(String channelId) async {
    _favoriteIds.remove(channelId);
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoritesKey, _favoriteIds.toList());
    } catch (_) {}
  }

  // ── Theme ─────────────────────────────────────────────────
  bool _isDark = true;
  bool get isDark => _isDark;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }

  // ── Data ──────────────────────────────────────────────────
  List<MatchModel> _liveMatches = [];
  List<MatchModel> _todayMatches = [];
  List<MatchModel> _upcomingMatches = [];
  List<MatchModel> _predictions = [];
  List<ChannelModel> _channels = [];
  List<ChannelModel> _liveChannels = [];
  List<NewsModel> _news = [];
  List<ScoreTournamentGroup> _scoreGroups = [];
  List<LiveEventMatch> _liveEventFootball = [];
  List<LiveEventMatch> _liveEventCricket = [];
  bool _liveEventsLoading = false;
  DateTime? _liveEventsLoadedAt;
  static const _liveEventsTtl = Duration(minutes: 5);
  Map<String, bool> _streamHealth = {};
  final Map<String, bool> _streamUrlHealth = {};
  final Set<String> _pendingStreamUrlChecks = {};
  final Map<String, DateTime> _streamHealthAt = {};
  bool _streamHealthLoading = false;
  final Set<String> _pendingStreamHealthIds = {};
  final List<String> _streamHealthQueue = [];
  bool _streamHealthWorkerActive = false;
  static const _streamHealthTtl = Duration(minutes: 10);
  static const _healthBatchSize = 5;
  static const _globalScanCap = 120;

  List<MatchModel> get liveMatches => _liveMatches;
  List<MatchModel> get todayMatches => _todayMatches;
  List<MatchModel> get upcomingMatches => _upcomingMatches;
  List<MatchModel> get predictions => _predictions;
  List<ChannelModel> get channels => _channels;
  List<ChannelModel> get liveChannels => _liveChannels;
  List<NewsModel> get news => _news;
  List<ScoreTournamentGroup> get scoreTournamentGroups => _scoreGroups;
  List<LiveEventMatch> get liveEventFootball => _liveEventFootball;
  List<LiveEventMatch> get liveEventCricket => _liveEventCricket;
  bool get liveEventsLoading => _liveEventsLoading;
  bool get streamHealthLoading => _streamHealthLoading;

  /// LIVE badge only when central health cache says URL returned HTTP 200.
  bool isStreamLive(ChannelModel channel) =>
      _streamHealth[channel.id] == true;

  bool isStreamHealthPending(ChannelModel channel) =>
      _pendingStreamHealthIds.contains(channel.id);

  bool hasStreamHealthResult(ChannelModel channel) =>
      _streamHealth.containsKey(channel.id);

  bool isStreamUrlLive(String url) => _streamUrlHealth[url] == true;

  bool isStreamUrlHealthPending(String url) =>
      _pendingStreamUrlChecks.contains(url);

  bool hasStreamUrlHealthResult(String url) =>
      _streamUrlHealth.containsKey(url);

  /// Channels shown under the player ("more" list).
  List<ChannelModel> playerRelatedChannels({
    required String currentTitle,
    String? currentUrl,
    required String relatedCategory,
    List<ChannelModel>? fallback,
  }) {
    final current = channelForStream(currentUrl ?? '') ??
        findChannel(name: currentTitle);
    final hubRelated = ChannelHubProcessor.relatedForChannel(
      current,
      _channels,
      excludeUrl: currentUrl,
    );
    if (hubRelated.isNotEmpty) {
      return hubRelated;
    }

    final related = recommendedChannels(
      excludeStreamUrl: currentUrl,
      category: relatedCategory,
    );
    final source = related.isNotEmpty ? related : (fallback ?? const []);
    return source
        .where((c) => c.streamUrl.isNotEmpty && c.name != currentTitle)
        .take(12)
        .toList();
  }

  bool _needsStreamHealthCheck(ChannelModel c, {bool force = false}) {
    if (!c.allStreams.any((l) => l.url.isNotEmpty)) return false;
    if (force) return true;
    final checkedAt = _streamHealthAt[c.id];
    if (checkedAt == null || !_streamHealth.containsKey(c.id)) return true;
    return DateTime.now().difference(checkedAt) > _streamHealthTtl;
  }

  ChannelModel? _channelById(String id) {
    for (final c in _channels) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _clearStreamHealthCache() {
    _streamHealth.clear();
    _streamHealthAt.clear();
    _streamHealthQueue.clear();
    _pendingStreamHealthIds.clear();
    _streamHealthLoading = false;
    _streamHealthWorkerActive = false;
  }

  /// Single queue for all m3u8 checks — UI reads [_streamHealth] only.
  Future<void> ensureStreamHealth(
    Iterable<ChannelModel> channels, {
    bool priority = false,
    bool force = false,
  }) async {
    var scheduled = false;
    for (final c in channels) {
      if (!_needsStreamHealthCheck(c, force: force)) continue;
      if (_pendingStreamHealthIds.contains(c.id)) continue;

      _pendingStreamHealthIds.add(c.id);
      _streamHealthQueue.remove(c.id);
      if (priority) {
        _streamHealthQueue.insert(0, c.id);
      } else if (!_streamHealthQueue.contains(c.id)) {
        _streamHealthQueue.add(c.id);
      }
      scheduled = true;
    }

    if (!scheduled) return;
    _streamHealthLoading = true;
    notifyListeners();
    unawaited(_drainStreamHealthQueue());
  }

  Future<void> _drainStreamHealthQueue() async {
    if (_streamHealthWorkerActive) return;
    _streamHealthWorkerActive = true;

    while (_streamHealthQueue.isNotEmpty) {
      final take = _streamHealthQueue.length > _healthBatchSize
          ? _healthBatchSize
          : _streamHealthQueue.length;
      final batchIds = _streamHealthQueue.sublist(0, take);
      _streamHealthQueue.removeRange(0, take);

      final batch = batchIds
          .map(_channelById)
          .whereType<ChannelModel>()
          .toList();

      if (batch.isNotEmpty) {
        try {
          final partial = await StreamHealthService.checkChannels(batch);
          _streamHealth.addAll(partial);
          final now = DateTime.now();
          for (final c in batch) {
            _streamHealthAt[c.id] = now;
          }
        } catch (_) {
          final now = DateTime.now();
          for (final c in batch) {
            _streamHealth.putIfAbsent(c.id, () => false);
            _streamHealthAt[c.id] = now;
          }
        }
        notifyListeners();
      }

      for (final id in batchIds) {
        _pendingStreamHealthIds.remove(id);
      }
    }

    _streamHealthWorkerActive = false;
    _streamHealthLoading =
        _pendingStreamHealthIds.isNotEmpty || _streamHealthQueue.isNotEmpty;
    notifyListeners();
  }

  /// One background scan after channels load (sports first, capped).
  void _scheduleGlobalStreamHealthScan() {
    if (_channels.isEmpty) return;

    final sports = _channels
        .where((c) => c.category == 'Sports' && c.streamUrl.isNotEmpty)
        .toList();
    final others = _liveChannels
        .where((c) => c.category != 'Sports')
        .take(_globalScanCap)
        .toList();

    unawaited(ensureStreamHealth(sports, priority: true));
    if (others.isNotEmpty) {
      unawaited(ensureStreamHealth(others));
    }
  }

  /// Back-compat alias — always routes through [ensureStreamHealth].
  Future<void> checkStreamHealthFor(
    Iterable<ChannelModel> channels, {
    bool force = false,
  }) =>
      ensureStreamHealth(channels, force: force);

  // ── Loading states ────────────────────────────────────────
  bool _matchesLoading = false;
  bool _channelsLoading = false;
  bool _newsLoading = false;

  bool get matchesLoading => _matchesLoading;
  bool get channelsLoading => _channelsLoading;
  bool get newsLoading => _newsLoading;

  // ── Error states ──────────────────────────────────────────
  String? _matchesError;
  String? _channelsError;
  String? _newsError;

  String? get matchesError => _matchesError;
  String? get channelsError => _channelsError;
  String? get newsError => _newsError;

  bool get hasChannelsError => _channelsError != null;
  bool get hasMatchesError => _matchesError != null;

  bool _scoresRequested = false;

  /// Lazy-load ESPN/Cricbuzz scores (News tab) — avoids blocking Home startup.
  Future<void> ensureMatchesLoaded() async {
    if (_matchesLoading) return;
    if (_scoresRequested && _scoreGroups.isNotEmpty) return;
    _scoresRequested = true;
    await loadMatches();
  }

  // ── Init ──────────────────────────────────────────────────
  Future<void> loadAll() async {
    await Future.wait([loadChannels(), loadNews()]);
  }

  /// Called by main.dart via AppProvider()..init()
  Future<void> init() async {
    await loadFavorites();
    await loadAll();
  }

  /// Home category chips (display label → internal category).
  static const homeCategories = <Map<String, String>>[
    {'icon': '⚽', 'label': 'Sports', 'cat': 'Sports'},
    {'icon': '🎭', 'label': 'Entertainment', 'cat': 'Entertainment'},
    {'icon': '🎬', 'label': 'Movies', 'cat': 'Movies'},
    {'icon': '🇰🇷', 'label': 'KDrama', 'cat': 'KDrama'},
    {'icon': '🇧🇩', 'label': 'Bangla', 'cat': 'Bangladesh'},
  ];

  // ── Matches ───────────────────────────────────────────────
  Future<void> loadMatches() async {
    _matchesLoading = true;
    _matchesError = null;
    notifyListeners();
    try {
      _scoreGroups = await ScoreService.fetchTodayScoreboards();
      final fetched = _scoreGroups
          .expand((g) => g.matches)
          .map(_attachStreamToMatch)
          .toList();

      if (fetched.isNotEmpty) {
        _liveMatches = fetched;
        _predictions = fetched.take(6).toList();
      } else {
        _liveMatches = _demoLive.map(_attachStreamToMatch).toList();
        _predictions = _liveMatches;
      }

      _todayMatches = [
        ..._liveMatches,
        ..._demoToday.where((m) => !_liveMatches.any((l) => l.id == m.id)),
      ].map(_attachStreamToMatch).toList();

      _upcomingMatches =
          _demoUpcoming.map(_attachStreamToMatch).toList();
    } catch (e) {
      _matchesError = e.toString();
      _liveMatches = _demoLive;
      _todayMatches = _demoToday;
      _upcomingMatches = _demoUpcoming;
      _predictions = _demoLive;
    } finally {
      _matchesLoading = false;
      notifyListeners();
    }
  }

  // ── News ──────────────────────────────────────────────────
  Future<void> loadNews() async {
    _newsLoading = true;
    _newsError = null;
    notifyListeners();
    try {
      final fetched = await NewsService.fetchLatest();
      _news = fetched.isNotEmpty ? fetched : _demoNews;
    } catch (e) {
      _newsError = e.toString();
      _news = _demoNews;
    } finally {
      _newsLoading = false;
      notifyListeners();
    }
  }

  // ── Channels ──────────────────────────────────────────────
  Future<void> loadChannels({String? category}) async {
    _channelsLoading = true;
    _channelsError = null;
    notifyListeners();

    List<ChannelModel> m3uChannels = [];
    try {
      final res = await http.get(
        Uri.parse(_m3uUrl),
        headers: {'User-Agent': mozillaUA},
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        m3uChannels = _parseM3U(res.body);
      }
    } on TimeoutException {
      _channelsError = 'Connection timed out. Showing saved channels.';
    } catch (_) {
      // Silent — hardcoded channels will still load
    }

    try {
      final bundled = await rootBundle
          .loadString('assets/data/user_playlist.m3u')
          .timeout(const Duration(seconds: 8));
      m3uChannels = ExtraChannels.merge(m3uChannels, _parseM3U(bundled));
    } catch (_) {
      // Optional bundled playlist — place file at assets/data/user_playlist.m3u
    }

    final merged = ExtraChannels.merge(
      ExtraChannels.merge(
        ExtraChannels.merge(
          ExtraChannels.merge(_hardcodedChannels, ExtraChannels.userChannels),
          ExtraChannels.all,
        ),
        ToffeeChannels.all,
      ),
      m3uChannels,
    );
    final all = ChannelHubProcessor.expand(ChannelCatalog.normalizeAll(merged));
    _channels = all;
    _liveChannels = all.where((c) => c.streamUrl.isNotEmpty).toList();
    _channelsLoading = false;
    notifyListeners();
    // Defer heavy work so Home/Live UI paints first (categories + channel list).
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_channels.isEmpty) return;
      unawaited(loadLiveEvents());
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (_channels.isEmpty) return;
      _scheduleGlobalStreamHealthScan();
    });
  }

  // ── Refresh ───────────────────────────────────────────────
  Future<void> refresh() async {
    ScoreService.clearCache();
    final reloadScores = _scoresRequested;
    _clearStreamHealthCache();
    _channels = [];
    _liveChannels = [];
    _liveEventFootball = [];
    _liveEventCricket = [];
    _liveEventsLoadedAt = null;
    _scoresRequested = false;
    await loadAll();
    if (reloadScores) {
      _scoresRequested = true;
      await loadMatches();
    }
  }

  // ── Search ───────────────────────────────────────────────
  List<ChannelModel> search(String q) {
    if (q.trim().isEmpty) return _channels;
    final ql = q.toLowerCase();
    return _channels
        .where(
          (c) =>
              c.name.toLowerCase().contains(ql) ||
              c.category.toLowerCase().contains(ql) ||
              c.country.toLowerCase().contains(ql),
        )
        .toList();
  }

  List<ChannelModel> byCategory(String cat) {
    if (cat == 'All') return _channels;
    final normalized = cat == 'Bangla' ? 'Bangladesh' : cat;
    return _channels.where((c) => c.category == normalized).toList();
  }

  bool get hasLiveEventsData =>
      _liveEventFootball.isNotEmpty || _liveEventCricket.isNotEmpty;

  /// Cached live events — skips network if data is fresh unless [force].
  Future<void> loadLiveEvents({bool force = false}) async {
    if (_channels.isEmpty) return;

    final cacheFresh = _liveEventsLoadedAt != null &&
        DateTime.now().difference(_liveEventsLoadedAt!) < _liveEventsTtl;
    if (!force && hasLiveEventsData && cacheFresh) {
      // #region agent log
      agentDebugLog(
        location: 'app_provider.dart:loadLiveEvents',
        message: 'cache hit — skip fetch',
        hypothesisId: 'H2',
      );
      // #endregion
      return;
    }

    // #region agent log
    final loadStart = DateTime.now().millisecondsSinceEpoch;
    agentDebugLog(
      location: 'app_provider.dart:loadLiveEvents',
      message: 'fetch start',
      hypothesisId: 'H2',
      data: {'force': force, 'hadCache': hasLiveEventsData},
    );
    // #endregion

    // Spinner only in the Live Events header — avoid rebuilding the whole Home tab.
    if (!hasLiveEventsData) {
      _liveEventsLoading = true;
      notifyListeners();
    }

    try {
      final bundle = await LiveEventsService.fetch(_channels);
      _liveEventFootball = bundle.football;
      _liveEventCricket = bundle.cricket;
      _liveEventsLoadedAt = DateTime.now();
    } catch (_) {
      if (!hasLiveEventsData) {
        _liveEventFootball = [];
        _liveEventCricket = [];
      }
    } finally {
      _liveEventsLoading = false;
      notifyListeners();
      // #region agent log
      agentDebugLog(
        location: 'app_provider.dart:loadLiveEvents',
        message: 'fetch done',
        hypothesisId: 'H2',
        data: {
          'ms': DateTime.now().millisecondsSinceEpoch - loadStart,
          'football': _liveEventFootball.length,
          'cricket': _liveEventCricket.length,
        },
      );
      // #endregion
    }
  }

  /// On-demand m3u8 check when user picks a channel (popup) — not on dialog open.
  Future<bool> checkChannelActiveNow(ChannelModel channel) async {
    if (!channel.allStreams.any((l) => l.url.isNotEmpty)) return false;

    _pendingStreamHealthIds.add(channel.id);
    notifyListeners();
    try {
      final ok = await StreamHealthService.isChannelActive(
        channel,
        timeout: const Duration(seconds: 3),
      );
      _streamHealth[channel.id] = ok;
      _streamHealthAt[channel.id] = DateTime.now();
      return ok;
    } catch (_) {
      _streamHealth[channel.id] = false;
      _streamHealthAt[channel.id] = DateTime.now();
      return false;
    } finally {
      _pendingStreamHealthIds.remove(channel.id);
      notifyListeners();
    }
  }

  /// Per-link health check for live-event popup rows.
  Future<bool> checkStreamUrlActiveNow(
    StreamLink link, {
    ChannelModel? channel,
  }) async {
    if (link.url.isEmpty) return false;
    _pendingStreamUrlChecks.add(link.url);
    notifyListeners();
    try {
      final ok = await StreamHealthService.isUrlActive(
        link.url,
        headers: link.headers,
        timeout: const Duration(seconds: 3),
      );
      _streamUrlHealth[link.url] = ok;
      if (channel != null) {
        _streamHealth[channel.id] = channel.allStreams.any(
          (l) => _streamUrlHealth[l.url] == true,
        );
        _streamHealthAt[channel.id] = DateTime.now();
      }
      return ok;
    } catch (_) {
      _streamUrlHealth[link.url] = false;
      return false;
    } finally {
      _pendingStreamUrlChecks.remove(link.url);
      notifyListeners();
    }
  }

  List<MatchModel> get scoreCardMatches =>
      _scoreGroups.expand((g) => g.matches).toList();

  /// International football + cricket (non franchise leagues).
  List<MatchModel> get internationalScoreMatches =>
      MatchGrouping.international(scoreCardMatches);

  /// Football Premier League + cricket franchise leagues (IPL, BPL, …).
  List<MatchModel> get premierLeagueScoreMatches =>
      MatchGrouping.premierLeague(scoreCardMatches);

  /// Live Events: live first, then scheduled by kickoff (BDT), then finished.
  List<LiveEventMatch> get sortedLiveEvents => LiveEventSort.sort([
        ..._liveEventFootball,
        ..._liveEventCricket,
      ]);

  ChannelModel? channelForStream(String url) {
    if (url.isEmpty) return null;
    try {
      return _channels.firstWhere((c) => c.matchesStreamUrl(url));
    } catch (_) {
      return null;
    }
  }

  ChannelModel? findChannel({String? id, String? name}) {
    for (final c in _channels) {
      if (id != null && c.id == id) return c;
      if (name != null && c.name.toLowerCase() == name.toLowerCase()) {
        return c;
      }
    }
    return null;
  }

  /// Related channels for the player — same [category] as the current stream when set.
  List<ChannelModel> recommendedChannels({
    String? excludeStreamUrl,
    String? category,
  }) {
    final normalized = _normalizeCategory(category);
    var list = _channels.where((c) => c.streamUrl.isNotEmpty);
    if (normalized != null) {
      list = list.where((c) => c.category == normalized);
    }
    final sorted = list.toList()
      ..sort((a, b) => b.viewers.compareTo(a.viewers));
    return sorted
        .where((c) => !c.matchesStreamUrl(excludeStreamUrl ?? ''))
        .take(12)
        .toList();
  }

  static String? _normalizeCategory(String? category) {
    if (category == null || category.isEmpty) return null;
    if (category == 'Bangla') return 'Bangladesh';
    return category;
  }

  /// Best category for related-channel list (fixes M3U mis-tags like Entertainment).
  String categoryForRelated(ChannelModel channel, {String? browseCategory}) {
    if (browseCategory != null && browseCategory.isNotEmpty) {
      return _normalizeCategory(browseCategory) ?? browseCategory;
    }
    final inferred = _mapCat(channel.currentShow, channel.name);
    final cat = channel.category;
    if (cat.isEmpty) return inferred;
    if (cat == 'Entertainment' && inferred != 'Entertainment') return inferred;
    if (cat == 'English' && inferred == 'Sports') return inferred;
    return cat;
  }

  static String relatedSectionLabel(String? category) {
    final c = category ?? '';
    switch (c) {
      case 'Sports':
        return 'MORE SPORTS CHANNELS';
      case 'Bangladesh':
      case 'Bangla':
        return 'MORE BANGLA CHANNELS';
      case 'Movies':
        return 'MORE MOVIE CHANNELS';
      case 'Entertainment':
        return 'MORE ENTERTAINMENT';
      case 'Hindi':
        return 'MORE HINDI CHANNELS';
      case 'English':
        return 'MORE ENGLISH CHANNELS';
      case 'Kids':
        return 'MORE KIDS CHANNELS';
      case 'KDrama':
        return 'MORE K-DRAMA CHANNELS';
      default:
        return c.isEmpty ? 'RELATED CHANNELS' : 'MORE ${c.toUpperCase()} CHANNELS';
    }
  }

  static const _footballKeywords = [
    'football',
    'epl',
    'premier',
    'bein',
    'sky sports football',
    'sky sports epl',
    'tnt sports',
    'eurosport',
    'f1',
  ];

  static const _cricketKeywords = [
    'cricket',
    'willow',
    'tsports',
    't sports',
    'star sports',
    'sony sports',
    'sony ten cricket',
    'ptv sports',
    'fancode',
  ];

  List<ChannelModel> _pickSportsChannels(List<String> keywords,
      {required int limit}) {
    final out = <ChannelModel>[];
    for (final c in _channels) {
      if (c.category != 'Sports' || c.streamUrl.isEmpty) continue;
      final name = c.name.toLowerCase();
      if (keywords.any(name.contains)) {
        out.add(c);
      }
      if (out.length >= limit) break;
    }
    if (out.length < limit) {
      for (final c in _channels) {
        if (c.category != 'Sports' || c.streamUrl.isEmpty) continue;
        if (out.any((x) => x.id == c.id)) continue;
        out.add(c);
        if (out.length >= limit) break;
      }
    }
    return out;
  }

  MatchModel _channelAsLiveEvent(ChannelModel c, String sport) => MatchModel(
        id: 'live_evt_${c.id}',
        sport: sport,
        teamA: c.name,
        teamB: sport == 'Football' ? 'Season Live' : 'Live Match',
        scoreA: '',
        scoreB: '',
        status: 'live',
        time: '● LIVE',
        channel: c.currentShow.isNotEmpty ? c.currentShow : c.name,
        streamUrl: c.streamUrl,
        matchDate: DateTime.now(),
      );

  MatchModel _attachStreamToMatch(MatchModel m) {
    if (m.streamUrl.isNotEmpty) return m;
    final sport = m.sport.toLowerCase();
    final keywords = sport.contains('foot') || sport.contains('soccer')
        ? _footballKeywords
        : _cricketKeywords;
    final ch = _pickSportsChannels(keywords, limit: 1);
    if (ch.isEmpty) return m;
    return m.copyWith(
      streamUrl: ch.first.streamUrl,
      channel: ch.first.name,
    );
  }

  List<String> get categories {
    final cats = _channels.map((c) => c.category).toSet().toList()..sort();
    return ['All', ...cats];
  }

  // ════════════════════════════════════════════════════════════
  // HARDCODED CHANNELS
  // ════════════════════════════════════════════════════════════
  static final List<ChannelModel> _hardcodedChannels = [
    // ── Sports ───────────────────────────────────────────────
    ChannelModel(
      id: 's1',
      name: 'T Sports',
      category: 'Sports',
      country: 'Bangladesh',
      isLive: true,
      viewers: 22000,
      currentShow: 'Live Cricket',
      streamUrl: 'http://198.195.239.50:8095/Tsports/tracks-v1a1/mono.m3u8',
      alternateStreams: [
        StreamLink(
          url: 'https://bldcmprod-cdn.toffeelive.com/cdn/live/ten_cricket/playlist.m3u8',
          label: 'Toffee',
          headers: {
            'User-Agent': ToffeeHeaders.userAgent,
            'Cookie': ToffeeHeaders.cookieHeader,
            'Referer': 'https://toffeelive.com/',
          },
        ),
        StreamLink(
          url: 'http://198.195.239.50:8095/WiLLow/index.m3u8',
          label: 'Link 3',
        ),
      ],
    ),
    ChannelModel(
      id: 's2',
      name: 'Willow HD',
      category: 'Sports',
      country: 'USA',
      isLive: true,
      viewers: 18500,
      currentShow: 'Cricket Live',
      streamUrl: 'http://198.195.239.50:8095/WiLLow/index.m3u8',
    ),
    ChannelModel(
      id: 's3',
      name: 'PTV Sports (Old)',
      category: 'Sports',
      country: 'Pakistan',
      isLive: true,
      viewers: 9200,
      currentShow: 'PSL Live',
      streamUrl: 'http://198.195.239.50:8095/PTV-kutta/video.m3u8',
    ),
    ChannelModel(
      id: 's4',
      name: 'Star Sports Hindi',
      category: 'Sports',
      country: 'India',
      isLive: true,
      viewers: 15000,
      currentShow: 'Live Sports',
      streamUrl: 'https://starsportshindiii.pages.dev/index.m3u8',
    ),
    ChannelModel(
      id: 's5',
      name: 'Sony Ten 1 HD',
      category: 'Sports',
      country: 'India',
      isLive: true,
      viewers: 12000,
      currentShow: 'Live Sports',
      streamUrl: 'https://playyonogames.in/sliv/stream.m3u8?id=1000009276',
      headers: {
        'User-Agent': mozillaUA,
        'Referer': 'https://playyonogames.in/',
      },
    ),
    ChannelModel(
      id: 's6',
      name: 'Sony Ten 2 HD',
      category: 'Sports',
      country: 'India',
      isLive: true,
      viewers: 10000,
      currentShow: 'Live Sports',
      streamUrl: 'https://playyonogames.in/sliv/stream.m3u8?id=1000009277',
      headers: {
        'User-Agent': mozillaUA,
        'Referer': 'https://playyonogames.in/',
      },
    ),
    ChannelModel(
      id: 's7',
      name: 'Sony Ten 3 HD',
      category: 'Sports',
      country: 'India',
      isLive: true,
      viewers: 8000,
      currentShow: 'Live Sports',
      streamUrl: 'https://playyonogames.in/sliv/stream.m3u8?id=1000009278',
      headers: {
        'User-Agent': mozillaUA,
        'Referer': 'https://playyonogames.in/',
      },
    ),
    ChannelModel(
      id: 's8',
      name: 'Sony Ten 5 HD',
      category: 'Sports',
      country: 'India',
      isLive: true,
      viewers: 7000,
      currentShow: 'Live Sports',
      streamUrl: 'https://playyonogames.in/sliv/stream.m3u8?id=1000009275',
      headers: {
        'User-Agent': mozillaUA,
        'Referer': 'https://playyonogames.in/',
      },
    ),
    ChannelModel(
      id: 's9',
      name: 'Star Sports 1 Hindi',
      category: 'Sports',
      country: 'India',
      isLive: true,
      viewers: 14000,
      currentShow: 'Live Cricket',
      streamUrl: 'http://Rochdi@starshare.net:80/live/Suryaaa/SURYAAAA/211.ts',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's10',
      name: 'Star Sports 2 Hindi HD',
      category: 'Sports',
      country: 'India',
      isLive: true,
      viewers: 11000,
      currentShow: 'Live Sports',
      streamUrl: 'http://103.161.153.165:8000/play/a04m/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's11',
      name: 'Star Sports 1',
      category: 'Sports',
      country: 'India',
      isLive: true,
      viewers: 18000,
      currentShow: 'Live Cricket',
      streamUrl: 'http://103.161.153.165:8000/play/stp1h/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's12',
      name: 'Star Sports 2 HD',
      category: 'Sports',
      country: 'India',
      isLive: true,
      viewers: 13000,
      currentShow: 'Live Sports',
      streamUrl: 'http://103.161.153.165:8000/play/stp2h/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's13',
      name: 'Star Sports 3',
      category: 'Sports',
      country: 'India',
      isLive: true,
      viewers: 9000,
      currentShow: 'Live Sports',
      streamUrl: 'http://Rochdi@starshare.net:80/live/Suryaaa/SURYAAAA/1080.ts',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's14',
      name: 'Star Sports Select 1 HD',
      category: 'Sports',
      country: 'India',
      isLive: true,
      viewers: 8000,
      currentShow: 'Live Sports',
      streamUrl: 'http://103.161.153.165:8000/play/starspsl1hd/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's15',
      name: 'Star Sports Select 2 HD',
      category: 'Sports',
      country: 'India',
      isLive: true,
      viewers: 7000,
      currentShow: 'Live Sports',
      streamUrl: 'http://103.161.153.165:8000/play/starspsel2/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's16',
      name: 'Star Sports Khel',
      category: 'Sports',
      country: 'India',
      isLive: true,
      viewers: 5000,
      currentShow: 'Live Sports',
      streamUrl: 'http://103.175.73.12:8080/live/151/151_0.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's17',
      name: 'A Sports',
      category: 'Sports',
      country: 'Pakistan',
      isLive: true,
      viewers: 8000,
      currentShow: 'Live Sports',
      streamUrl:
          'https://roarzone.geoclaster.xyz/main/stream.php?id=ZWRnZTIvYS1zcG9ydHM%3D&name=ASPORTS&format=.m3u8',
      headers: {
        'User-Agent': mozillaUA,
        'Referer': 'https://roarzone.geoclaster.xyz/',
      },
    ),
    ChannelModel(
      id: 's18',
      name: 'PTV Sports',
      category: 'Sports',
      country: 'Pakistan',
      isLive: true,
      viewers: 9000,
      currentShow: 'Live Sports',
      streamUrl:
          'https://roarzone.geoclaster.xyz/main/stream.php?id=ZWRnZTIvcHR2LXNwb3J0cw%3D%3D&name=PTV+spotrs&format=.m3u8',
      headers: {
        'User-Agent': mozillaUA,
        'Referer': 'https://roarzone.geoclaster.xyz/',
      },
    ),
    ChannelModel(
      id: 's19',
      name: 'Sky Sports Cricket',
      category: 'Sports',
      country: 'UK',
      isLive: true,
      viewers: 15000,
      currentShow: 'Live Cricket',
      streamUrl: 'http://6zirt9yx.otttv.pw/iptv/HEGN4VXXQQSYCA/9258/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's20',
      name: 'Sky Sports Football',
      category: 'Sports',
      country: 'UK',
      isLive: true,
      viewers: 20000,
      currentShow: 'Live Football',
      streamUrl: 'http://6zirt9yx.otttv.pw/iptv/HEGN4VXXQQSYCA/9289/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's21',
      name: 'Sky Sports Main Event',
      category: 'Sports',
      country: 'UK',
      isLive: true,
      viewers: 18000,
      currentShow: 'Live Sports',
      streamUrl: 'http://6zirt9yx.otttv.pw/iptv/HEGN4VXXQQSYCA/7337/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's22',
      name: 'Sky Sports EPL',
      category: 'Sports',
      country: 'UK',
      isLive: true,
      viewers: 25000,
      currentShow: 'Premier League',
      streamUrl: 'http://6zirt9yx.otttv.pw/iptv/HEGN4VXXQQSYCA/9334/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's23',
      name: 'Sky Sports Action',
      category: 'Sports',
      country: 'UK',
      isLive: true,
      viewers: 10000,
      currentShow: 'Live Sports',
      streamUrl: 'http://6zirt9yx.otttv.pw/iptv/HEGN4VXXQQSYCA/9155/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's24',
      name: 'Sky Sports Golf',
      category: 'Sports',
      country: 'UK',
      isLive: true,
      viewers: 5000,
      currentShow: 'Live Golf',
      streamUrl: 'http://6zirt9yx.otttv.pw/iptv/HEGN4VXXQQSYCA/9293/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's25',
      name: 'Sky Sports Mix',
      category: 'Sports',
      country: 'UK',
      isLive: true,
      viewers: 6000,
      currentShow: 'Live Sports',
      streamUrl: 'http://6zirt9yx.otttv.pw/iptv/HEGN4VXXQQSYCA/9310/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's26',
      name: 'Sky Sports News',
      category: 'Sports',
      country: 'UK',
      isLive: true,
      viewers: 8000,
      currentShow: 'Sports News',
      streamUrl: 'http://6zirt9yx.otttv.pw/iptv/HEGN4VXXQQSYCA/9314/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's27',
      name: 'Sky Sports Tennis',
      category: 'Sports',
      country: 'UK',
      isLive: true,
      viewers: 7000,
      currentShow: 'Live Tennis',
      streamUrl: 'http://6zirt9yx.otttv.pw/iptv/HEGN4VXXQQSYCA/6546/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's28',
      name: 'TNT Sports',
      category: 'Sports',
      country: 'UK',
      isLive: true,
      viewers: 12000,
      currentShow: 'Live Sports',
      streamUrl: 'http://46.225.94.157/hls/tnt/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's29',
      name: 'TNT Sports 1',
      category: 'Sports',
      country: 'UK',
      isLive: true,
      viewers: 10000,
      currentShow: 'Live Sports',
      streamUrl:
          'http://qe7abbli.megatv.fun/iptv/LBHN7YM3AWPMFD8DNH6SD3GR/6566/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's30',
      name: 'TNT Sports 2',
      category: 'Sports',
      country: 'UK',
      isLive: true,
      viewers: 9000,
      currentShow: 'Live Sports',
      streamUrl:
          'http://qe7abbli.megatv.fun/iptv/LBHN7YM3AWPMFD8DNH6SD3GR/2506/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's31',
      name: 'TNT Sports 3',
      category: 'Sports',
      country: 'UK',
      isLive: true,
      viewers: 8000,
      currentShow: 'Live Sports',
      streamUrl:
          'http://qe7abbli.megatv.fun/iptv/LBHN7YM3AWPMFD8DNH6SD3GR/6564/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's32',
      name: 'TNT Sports 4',
      category: 'Sports',
      country: 'UK',
      isLive: true,
      viewers: 7000,
      currentShow: 'Live Sports',
      streamUrl:
          'http://75be7132.rostelekom.xyz/iptv/R3A7B6MZZFDCUL/19054/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's33',
      name: 'Willow Cricket',
      category: 'Sports',
      country: 'USA',
      isLive: true,
      viewers: 16000,
      currentShow: 'Cricket Live',
      streamUrl: 'http://Rochdi@starshare.net:80/live/Suryaaa/SURYAAAA/215.ts',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's34',
      name: 'Willow 2',
      category: 'Sports',
      country: 'USA',
      isLive: true,
      viewers: 14000,
      currentShow: 'Cricket Live',
      streamUrl:
          'http://Rochdi@starshare.net:80/live/Suryaaa/SURYAAAA/675820.ts',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's35',
      name: 'FOX Sports',
      category: 'Sports',
      country: 'USA',
      isLive: true,
      viewers: 20000,
      currentShow: 'Live Sports',
      streamUrl:
          'http://y3fqd48g.megatv.fun/iptv/NRLXRWSBWBPLN4/19146/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's36',
      name: 'ESPN Premium',
      category: 'Sports',
      country: 'USA',
      isLive: true,
      viewers: 22000,
      currentShow: 'Live Sports',
      streamUrl: 'http://46.225.94.157/hls/espn/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's37',
      name: 'beIN Sports 1 HD',
      category: 'Sports',
      country: 'Qatar',
      isLive: true,
      viewers: 18000,
      currentShow: 'Live Football',
      streamUrl:
          'http://Rochdi@starshare.net:80/live/Suryaaa/SURYAAAA/652310.ts',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's38',
      name: 'beIN Sports 2 HD',
      category: 'Sports',
      country: 'Qatar',
      isLive: true,
      viewers: 15000,
      currentShow: 'Live Sports',
      streamUrl:
          'http://Rochdi@starshare.net:80/live/Suryaaa/SURYAAAA/652311.ts',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's39',
      name: 'beIN Sports 3 HD',
      category: 'Sports',
      country: 'Qatar',
      isLive: true,
      viewers: 12000,
      currentShow: 'Live Sports',
      streamUrl:
          'http://Rochdi@starshare.net:80/live/Suryaaa/SURYAAAA/652312.ts',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's40',
      name: 'beIN Sports 4 HD',
      category: 'Sports',
      country: 'Qatar',
      isLive: true,
      viewers: 10000,
      currentShow: 'Live Sports',
      streamUrl:
          'http://Rochdi@starshare.net:80/live/Suryaaa/SURYAAAA/652313.ts',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's41',
      name: 'beIN Sports 5 HD',
      category: 'Sports',
      country: 'Qatar',
      isLive: true,
      viewers: 8000,
      currentShow: 'Live Sports',
      streamUrl:
          'http://Rochdi@starshare.net:80/live/Suryaaa/SURYAAAA/652314.ts',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's42',
      name: 'beIN Sports 6 HD',
      category: 'Sports',
      country: 'Qatar',
      isLive: true,
      viewers: 7000,
      currentShow: 'Live Sports',
      streamUrl:
          'http://Rochdi@starshare.net:80/live/Suryaaa/SURYAAAA/652315.ts',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's43',
      name: 'beIN Sports 7 HD',
      category: 'Sports',
      country: 'Qatar',
      isLive: true,
      viewers: 6000,
      currentShow: 'Live Sports',
      streamUrl:
          'http://Rochdi@starshare.net:80/live/Suryaaa/SURYAAAA/652316.ts',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's44',
      name: 'beIN Sports 8 HD',
      category: 'Sports',
      country: 'Qatar',
      isLive: true,
      viewers: 5000,
      currentShow: 'Live Sports',
      streamUrl:
          'http://Rochdi@starshare.net:80/live/Suryaaa/SURYAAAA/652317.ts',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's45',
      name: 'beIN Sports 9 HD',
      category: 'Sports',
      country: 'Qatar',
      isLive: true,
      viewers: 5000,
      currentShow: 'Live Sports',
      streamUrl:
          'http://Rochdi@starshare.net:80/live/Suryaaa/SURYAAAA/652318.ts',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's46',
      name: 'Eurosport 1',
      category: 'Sports',
      country: 'UK',
      isLive: true,
      viewers: 10000,
      currentShow: 'Live Sports',
      streamUrl: 'http://151.80.18.177:86/Eurosport_HD/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's47',
      name: 'Eurosport 2',
      category: 'Sports',
      country: 'UK',
      isLive: true,
      viewers: 8000,
      currentShow: 'Live Sports',
      streamUrl: 'http://151.80.18.177:86/Eurosport_2_HD/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's48',
      name: 'Bein Sports 1',
      category: 'Sports',
      country: 'Qatar',
      isLive: true,
      viewers: 16000,
      currentShow: 'Live Football',
      streamUrl:
          'http://Rochdi@starshare.net:80/live/Suryaaa/SURYAAAA/415625.ts',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's49',
      name: 'Bein Sports 2',
      category: 'Sports',
      country: 'Qatar',
      isLive: true,
      viewers: 13000,
      currentShow: 'Live Sports',
      streamUrl:
          'http://Rochdi@starshare.net:80/live/Suryaaa/SURYAAAA/415626.ts',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's50',
      name: 'Bein Sports 3',
      category: 'Sports',
      country: 'Qatar',
      isLive: true,
      viewers: 11000,
      currentShow: 'Live Sports',
      streamUrl:
          'http://Rochdi@starshare.net:80/live/Suryaaa/SURYAAAA/415627.ts',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's51',
      name: 'Sky Sport NZ 1',
      category: 'Sports',
      country: 'NZ',
      isLive: true,
      viewers: 5000,
      currentShow: 'Live Sports',
      streamUrl: 'https://7pal.short.gy/skyspt1nz',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's52',
      name: 'Sky Sport NZ 2',
      category: 'Sports',
      country: 'NZ',
      isLive: true,
      viewers: 4000,
      currentShow: 'Live Sports',
      streamUrl: 'https://7pal.short.gy/skyspt2nz',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's53',
      name: 'Sky Sport NZ 3',
      category: 'Sports',
      country: 'NZ',
      isLive: true,
      viewers: 3000,
      currentShow: 'Live Sports',
      streamUrl: 'https://7pal.short.gy/skyspt3nz',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's54',
      name: 'Sky Sport NZ 4',
      category: 'Sports',
      country: 'NZ',
      isLive: true,
      viewers: 3000,
      currentShow: 'Live Sports',
      streamUrl: 'https://7pal.short.gy/skyspt4nz',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's55',
      name: 'Sky Sport NZ 5',
      category: 'Sports',
      country: 'NZ',
      isLive: true,
      viewers: 2000,
      currentShow: 'Live Sports',
      streamUrl: 'https://7pal.short.gy/skyspt5nz',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's56',
      name: 'Sky Sport NZ Premier League',
      category: 'Sports',
      country: 'NZ',
      isLive: true,
      viewers: 4000,
      currentShow: 'Premier League',
      streamUrl: 'https://7pal.short.gy/skyspt8nz',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's57',
      name: 'Fancode Live 1',
      category: 'Sports',
      country: 'India',
      isLive: true,
      viewers: 30000,
      currentShow: 'Live Cricket',
      streamUrl:
          'https://a166aivottlinear-a.akamaihd.net/OTTB/sin-nitro/live/clients/dash/enc/inpyms8ezu/out/v1/1084d5c9a97a4c5b9f9554c88f486646/cenc.mpd',
      headers: {'User-Agent': mozillaUA, 'Referer': 'https://www.fancode.com/'},
    ),
    ChannelModel(
      id: 's58',
      name: 'Fancode Live 2',
      category: 'Sports',
      country: 'India',
      isLive: true,
      viewers: 25000,
      currentShow: 'Live Sports',
      streamUrl:
          'https://otte.live.fly.ww.aiv-cdn.net/sin-nitro/live/clients/dash-sd/enc/v8g0dlo4z8/out/v1/946019f85dc64ae99ff9ce64a9727a62/cenc-sd.mpd',
      headers: {'User-Agent': mozillaUA, 'Referer': 'https://www.fancode.com/'},
    ),
    ChannelModel(
      id: 's59',
      name: 'Sky Sport NZ 6',
      category: 'Sports',
      country: 'NZ',
      isLive: true,
      viewers: 2000,
      currentShow: 'Live Sports',
      streamUrl: 'https://7pal.short.gy/skyspt6nz',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 's60',
      name: 'Sky Sport NZ 7',
      category: 'Sports',
      country: 'NZ',
      isLive: true,
      viewers: 2000,
      currentShow: 'Live Sports',
      streamUrl: 'https://7pal.short.gy/skyspt7nz',
      headers: {'User-Agent': mozillaUA},
    ),
    // ── Toffee Sports ─────────────────────────────────────────
    ChannelModel(
      id: 'st1',
      name: 'Sony Sports Ten 1 HD (Toffee)',
      category: 'Sports',
      country: 'Bangladesh',
      isLive: true,
      viewers: 20000,
      currentShow: 'Live Cricket',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/sony_sports_1_hd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'st2',
      name: 'Sony Sports Ten 2 HD (Toffee)',
      category: 'Sports',
      country: 'Bangladesh',
      isLive: true,
      viewers: 18000,
      currentShow: 'Live Sports',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/sony_sports_2_hd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'st3',
      name: 'Sony Sports Ten 5 HD (Toffee)',
      category: 'Sports',
      country: 'Bangladesh',
      isLive: true,
      viewers: 15000,
      currentShow: 'Live Sports',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/sony_sports_5_hd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'st4',
      name: 'Sony Ten Cricket (Toffee)',
      category: 'Sports',
      country: 'Bangladesh',
      isLive: true,
      viewers: 22000,
      currentShow: 'Live Cricket',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/ten_cricket/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'st5',
      name: 'Euro Sport HD (Toffee)',
      category: 'Sports',
      country: 'Bangladesh',
      isLive: true,
      viewers: 8000,
      currentShow: 'Live Sports',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/euro_sports_hd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'st6',
      name: 'Toffee Sports VIP',
      category: 'Sports',
      country: 'Bangladesh',
      isLive: true,
      viewers: 25000,
      currentShow: 'Sports Highlights',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/sports_highlights/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),

    // ── Bangladesh ────────────────────────────────────────────
    ChannelModel(
      id: 'b1',
      name: 'Nagorik TV',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 4100,
      currentShow: 'Bangla Program',
      streamUrl: 'http://198.195.239.50:8095/nagorik/tracks-v1a1/mono.m3u8',
      alternateStreams: const [
        StreamLink(
          url: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1718/output/index.m3u8',
          label: 'Link 2',
        ),
      ],
    ),
    ChannelModel(
      id: 'b2',
      name: 'News24 BD',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 6300,
      currentShow: 'News Live',
      streamUrl: 'http://198.195.239.50:8095/News24/tracks-v1a1/mono.m3u8',
    ),
    ChannelModel(
      id: 'b3',
      name: 'BTV',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 3000,
      currentShow: 'BTV Program',
      streamUrl: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1709/output/index.m3u8',
      alternateStreams: const [
        StreamLink(
          url: 'http://198.195.239.50:8095/BTV/tracks-v1a1/mono.m3u8',
          label: 'Link 2',
        ),
        StreamLink(
          url: 'https://live-stream.akhoni.com/BTV/index.m3u8',
          label: 'Link 3',
        ),
      ],
    ),
    ChannelModel(
      id: 'b4',
      name: 'Somoy TV',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 5000,
      currentShow: 'News',
      streamUrl: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1702/output/index.m3u8',
    ),
    ChannelModel(
      id: 'b5',
      name: 'Channel i',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 2800,
      currentShow: 'Drama',
      streamUrl: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1723/output/index.m3u8',
    ),
    ChannelModel(
      id: 'b6',
      name: 'Channel 24',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 3200,
      currentShow: 'News',
      streamUrl: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1703/output/index.m3u8',
    ),
    ChannelModel(
      id: 'b7',
      name: 'Bangla Vision',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 2100,
      currentShow: 'Entertainment',
      streamUrl: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1715/output/index.m3u8',
    ),
    ChannelModel(
      id: 'b8',
      name: 'NTV',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 4500,
      currentShow: 'Program',
      streamUrl: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1716/output/index.m3u8',
    ),
    ChannelModel(
      id: 'b9',
      name: 'Jamuna TV',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 5800,
      currentShow: 'News',
      streamUrl: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1701/output/index.m3u8',
    ),
    ChannelModel(
      id: 'b10',
      name: 'Ekkator TV',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 3100,
      currentShow: 'Program',
      streamUrl: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1705/output/index.m3u8',
    ),
    ChannelModel(
      id: 'b11',
      name: 'ATN News',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 2600,
      currentShow: 'News',
      streamUrl: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1706/output/index.m3u8',
    ),
    ChannelModel(
      id: 'b12',
      name: 'Star News BD',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 2000,
      currentShow: 'News',
      streamUrl: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1710/output/index.m3u8',
    ),
    ChannelModel(
      id: 'b13',
      name: 'Deepto TV',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 1800,
      currentShow: 'Program',
      streamUrl: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1711/output/index.m3u8',
    ),
    ChannelModel(
      id: 'b14',
      name: 'Sangshad TV',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 1200,
      currentShow: 'Parliament',
      streamUrl: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1713/output/index.m3u8',
    ),
    ChannelModel(
      id: 'b15',
      name: 'SATV',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 2300,
      currentShow: 'Entertainment',
      streamUrl: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1720/output/index.m3u8',
    ),
    ChannelModel(
      id: 'b16',
      name: 'Masranga TV',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 1900,
      currentShow: 'Drama',
      streamUrl: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1722/output/index.m3u8',
    ),
    ChannelModel(
      id: 'b17',
      name: 'Islamic TV',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 3500,
      currentShow: 'Islamic Program',
      streamUrl: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1724/output/index.m3u8',
    ),
    ChannelModel(
      id: 'b18',
      name: 'Deshi TV',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 1500,
      currentShow: 'Program',
      streamUrl: 'https://deshitv.deshitv24.net/live/myStream/playlist.m3u8',
    ),
    ChannelModel(
      id: 'b19',
      name: 'Sangeet Bangla',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 800,
      currentShow: 'Music',
      streamUrl: 'https://cdn-4.pishow.tv/live/1143/master.m3u8',
    ),
    ChannelModel(
      id: 'b20',
      name: 'Bangla Waz',
      category: 'Bangladesh',
      country: 'Bangladesh',
      isLive: true,
      viewers: 4200,
      currentShow: 'Waz Mahfil',
      streamUrl:
          'https://cloudfrontnet.vercel.app/tplay/playout/209617/master.m3u8',
    ),

    // ── Hindi ─────────────────────────────────────────────────
    ChannelModel(
      id: 'h1',
      name: 'Star Gold Romance',
      category: 'Hindi',
      country: 'India',
      isLive: true,
      viewers: 5000,
      currentShow: 'Bollywood Movies',
      streamUrl: 'http://Rochdi@starshare.net:80/live/Suryaaa/SURYAAAA/972.ts',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 'h2',
      name: 'Star Gold 2 SD',
      category: 'Hindi',
      country: 'India',
      isLive: true,
      viewers: 4000,
      currentShow: 'Hindi Movies',
      streamUrl: 'http://iptvcasomsapi.jprdigital.in/x-media/C0390/master.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 'h3',
      name: 'Star Gold 2 HD',
      category: 'Hindi',
      country: 'India',
      isLive: true,
      viewers: 6000,
      currentShow: 'Hindi Movies',
      streamUrl:
          'http://Rochdi@starshare.net:80/live/Suryaaa/SURYAAAA/157081.ts',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 'h4',
      name: 'Star Gold Select HD',
      category: 'Hindi',
      country: 'India',
      isLive: true,
      viewers: 7000,
      currentShow: 'Hindi Movies',
      streamUrl: 'http://103.161.153.165:8000/play/a05b/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 'h5',
      name: 'Star Gold HD',
      category: 'Hindi',
      country: 'India',
      isLive: true,
      viewers: 9000,
      currentShow: 'Bollywood',
      streamUrl: 'http://103.161.153.165:8000/play/a00s/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 'h6',
      name: 'Star Bharat HD',
      category: 'Hindi',
      country: 'India',
      isLive: true,
      viewers: 8000,
      currentShow: 'Hindi Drama',
      streamUrl: 'http://103.161.153.165:8000/play/a00r/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 'h7',
      name: 'Colors Rishtey',
      category: 'Hindi',
      country: 'India',
      isLive: true,
      viewers: 7000,
      currentShow: 'Hindi Drama',
      streamUrl: 'http://103.175.73.12:8080/live/12/12_0.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 'h8',
      name: 'Sony Entertainment HD',
      category: 'Hindi',
      country: 'India',
      isLive: true,
      viewers: 12000,
      currentShow: 'Hindi Drama',
      streamUrl: 'https://playyonogames.in/sliv/stream.m3u8?id=1000009246',
      headers: {
        'User-Agent': mozillaUA,
        'Referer': 'https://playyonogames.in/',
      },
    ),
    ChannelModel(
      id: 'h9',
      name: 'Sony SAB HD',
      category: 'Hindi',
      country: 'India',
      isLive: true,
      viewers: 10000,
      currentShow: 'Comedy',
      streamUrl: 'https://playyonogames.in/sliv/stream.m3u8?id=1000009248',
      headers: {
        'User-Agent': mozillaUA,
        'Referer': 'https://playyonogames.in/',
      },
    ),
    ChannelModel(
      id: 'h10',
      name: 'Sony Pal',
      category: 'Hindi',
      country: 'India',
      isLive: true,
      viewers: 7000,
      currentShow: 'Hindi Drama',
      streamUrl: 'https://playyonogames.in/sliv/stream.m3u8?id=1000009273',
      headers: {
        'User-Agent': mozillaUA,
        'Referer': 'https://playyonogames.in/',
      },
    ),
    ChannelModel(
      id: 'h11',
      name: 'Sony WAH',
      category: 'Hindi',
      country: 'India',
      isLive: true,
      viewers: 5000,
      currentShow: 'Comedy',
      streamUrl: 'https://playyonogames.in/sliv/stream.m3u8?id=1000009253',
      headers: {
        'User-Agent': mozillaUA,
        'Referer': 'https://playyonogames.in/',
      },
    ),
    ChannelModel(
      id: 'h12',
      name: 'Sony BBC Earth HD',
      category: 'Hindi',
      country: 'India',
      isLive: true,
      viewers: 4000,
      currentShow: 'Documentary',
      streamUrl: 'https://playyonogames.in/sliv/stream.m3u8?id=1000009252',
      headers: {
        'User-Agent': mozillaUA,
        'Referer': 'https://playyonogames.in/',
      },
    ),
    ChannelModel(
      id: 'h13',
      name: 'MBC Bollywood',
      category: 'Hindi',
      country: 'India',
      isLive: true,
      viewers: 6000,
      currentShow: 'Bollywood',
      streamUrl: 'http://93.184.10.248/MBCBollywood/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 'h14',
      name: 'Stream 2',
      category: 'Hindi',
      country: 'Bangladesh',
      isLive: true,
      viewers: 3000,
      currentShow: 'Live',
      streamUrl: 'https://iptv.prisma.net.bd/hls/stream2/playlist.m3u8',
      headers: {
        'User-Agent': mozillaUA,
        'Referer': 'https://iptv.prisma.net.bd/',
      },
    ),
    ChannelModel(
      id: 'h15',
      name: 'Stream 3',
      category: 'Hindi',
      country: 'Bangladesh',
      isLive: true,
      viewers: 2500,
      currentShow: 'Live',
      streamUrl: 'https://iptv.prisma.net.bd/hls/stream3/playlist.m3u8',
      headers: {
        'User-Agent': mozillaUA,
        'Referer': 'https://iptv.prisma.net.bd/',
      },
    ),
    ChannelModel(
      id: 'h16',
      name: 'Stream 4',
      category: 'Hindi',
      country: 'Bangladesh',
      isLive: true,
      viewers: 2000,
      currentShow: 'Live',
      streamUrl: 'https://iptv.prisma.net.bd/hls/stream4/playlist.m3u8',
      headers: {
        'User-Agent': mozillaUA,
        'Referer': 'https://iptv.prisma.net.bd/',
      },
    ),
    ChannelModel(
      id: 'h17',
      name: 'Sony SAB (UK)',
      category: 'Hindi',
      country: 'UK',
      isLive: true,
      viewers: 6000,
      currentShow: 'Comedy',
      streamUrl:
          'http://206.212.244.71:8080/BRIDGITS@YAHOO.COM/BRIDGITS@2022/125809',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 'h18',
      name: 'Sony MAX (UK)',
      category: 'Hindi',
      country: 'UK',
      isLive: true,
      viewers: 5000,
      currentShow: 'Bollywood Movie',
      streamUrl: 'http://nocable.cc:8080/789588/114528/125814',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 'h19',
      name: 'Sony MAX 2 (USA)',
      category: 'Hindi',
      country: 'USA',
      isLive: true,
      viewers: 4000,
      currentShow: 'Bollywood Movie',
      streamUrl:
          'http://fortv.cc:8080/futrellconsulting@gmail.com/9u3djjNr02/125795',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 'h20',
      name: 'Food Food',
      category: 'Hindi',
      country: 'USA',
      isLive: true,
      viewers: 2000,
      currentShow: 'Cooking Show',
      streamUrl: 'http://nocable.cc:8080/789588/114528/125807',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 'h21',
      name: 'Sony (UK)',
      category: 'Hindi',
      country: 'UK',
      isLive: true,
      viewers: 5000,
      currentShow: 'Hindi Drama',
      streamUrl: 'http://ahostingportal.com:8000/62664054820/5271593547/3018',
      headers: {'User-Agent': mozillaUA},
    ),
    // ── Toffee Hindi ──────────────────────────────────────────
    ChannelModel(
      id: 'ht1',
      name: 'Sony Entertainment HD (Toffee)',
      category: 'Hindi',
      country: 'Bangladesh',
      isLive: true,
      viewers: 15000,
      currentShow: 'Hindi Drama',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/sonyentertainmnt_hd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'ht2',
      name: 'Sony SAB HD (Toffee)',
      category: 'Hindi',
      country: 'Bangladesh',
      isLive: true,
      viewers: 12000,
      currentShow: 'Comedy',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/sonysab_hd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'ht3',
      name: 'Zee TV HD (Toffee)',
      category: 'Hindi',
      country: 'Bangladesh',
      isLive: true,
      viewers: 10000,
      currentShow: 'Hindi Drama',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/zee_tv_hd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'ht4',
      name: '&TV HD (Toffee)',
      category: 'Hindi',
      country: 'Bangladesh',
      isLive: true,
      viewers: 5000,
      currentShow: 'Hindi Drama',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/and_tv_hd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'ht5',
      name: 'Sony Entertainment TV (Toffee)',
      category: 'Hindi',
      country: 'Bangladesh',
      isLive: true,
      viewers: 10000,
      currentShow: 'Hindi Drama',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/sony_entertainment/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),

    // ── Movies ────────────────────────────────────────────────
    ChannelModel(
      id: 'm1',
      name: 'Kolkata Movies',
      category: 'Movies',
      country: 'India',
      isLive: true,
      viewers: 3200,
      currentShow: 'Kolkata Movie',
      streamUrl:
          'https://cloudfrontnet.vercel.app/tplay/playout/209627/master.m3u8',
    ),
    ChannelModel(
      id: 'm2',
      name: 'Movie Bangla',
      category: 'Movies',
      country: 'Bangladesh',
      isLive: true,
      viewers: 2100,
      currentShow: 'Bangla Movie',
      streamUrl: 'http://alvetv.com/moviebanglatv/8080/index.m3u8',
    ),
    ChannelModel(
      id: 'm3',
      name: 'Star Utsav Movies',
      category: 'Movies',
      country: 'India',
      isLive: true,
      viewers: 4000,
      currentShow: 'Bollywood Movie',
      streamUrl: 'http://103.175.73.12:8080/live/42/42_0.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 'm4',
      name: 'Star Movies HD',
      category: 'Movies',
      country: 'India',
      isLive: true,
      viewers: 8000,
      currentShow: 'Hollywood Movie',
      streamUrl: 'http://103.175.242.10:8080/starmovies/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 'm5',
      name: 'Star Movies Select HD',
      category: 'Movies',
      country: 'India',
      isLive: true,
      viewers: 6000,
      currentShow: 'Hollywood Movie',
      streamUrl:
          'http://Rochdi@starshare.net:80/live/Suryaaa/SURYAAAA/98843.ts',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 'm6',
      name: 'Colors Cineplex Bollywood',
      category: 'Movies',
      country: 'India',
      isLive: true,
      viewers: 5000,
      currentShow: 'Bollywood Movie',
      streamUrl: 'http://103.175.73.12:8080/live/437/437_0.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 'm7',
      name: 'Colors Cineplex HD',
      category: 'Movies',
      country: 'India',
      isLive: true,
      viewers: 7000,
      currentShow: 'Hindi Movie',
      streamUrl: 'http://103.161.153.165:8000/play/a05e/index.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 'm8',
      name: 'Colors Cineplex Superhit',
      category: 'Movies',
      country: 'India',
      isLive: true,
      viewers: 5000,
      currentShow: 'Hindi Movie',
      streamUrl: 'http://103.175.73.12:8080/live/14/14_0.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 'm9',
      name: 'Colors Bangla Cinema',
      category: 'Movies',
      country: 'India',
      isLive: true,
      viewers: 4000,
      currentShow: 'Bangla Movie',
      streamUrl: 'http://103.180.212.191:3500/live/1657.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    ChannelModel(
      id: 'm10',
      name: 'Sony MAX HD',
      category: 'Movies',
      country: 'India',
      isLive: true,
      viewers: 9000,
      currentShow: 'Bollywood Movie',
      streamUrl: 'https://playyonogames.in/sliv/stream.m3u8?id=1000009247',
      headers: {
        'User-Agent': mozillaUA,
        'Referer': 'https://playyonogames.in/',
      },
    ),
    ChannelModel(
      id: 'm11',
      name: 'Sony MAX 2',
      category: 'Movies',
      country: 'India',
      isLive: true,
      viewers: 7000,
      currentShow: 'Bollywood Movie',
      streamUrl: 'https://playyonogames.in/sliv/stream.m3u8?id=1000044878',
      headers: {
        'User-Agent': mozillaUA,
        'Referer': 'https://playyonogames.in/',
      },
    ),
    ChannelModel(
      id: 'm12',
      name: 'Sony PIX HD',
      category: 'Movies',
      country: 'India',
      isLive: true,
      viewers: 6000,
      currentShow: 'Hollywood Movie',
      streamUrl: 'https://playyonogames.in/sliv/stream.m3u8?id=1000009258',
      headers: {
        'User-Agent': mozillaUA,
        'Referer': 'https://playyonogames.in/',
      },
    ),
    ChannelModel(
      id: 'm13',
      name: 'MAX 1',
      category: 'Movies',
      country: 'India',
      isLive: true,
      viewers: 4000,
      currentShow: 'Movie',
      streamUrl: 'http://103.180.212.191:3500/live/3418.m3u8',
      headers: {'User-Agent': mozillaUA},
    ),
    // ── Toffee Movies ─────────────────────────────────────────
    ChannelModel(
      id: 'mt1',
      name: 'Sony MAX HD (Toffee)',
      category: 'Movies',
      country: 'Bangladesh',
      isLive: true,
      viewers: 10000,
      currentShow: 'Bollywood Movie',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/sony_max_hd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'mt2',
      name: 'Sony MAX (Toffee)',
      category: 'Movies',
      country: 'Bangladesh',
      isLive: true,
      viewers: 8000,
      currentShow: 'Bollywood Movie',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/sony_max/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'mt3',
      name: 'Sony PIX HD (Toffee)',
      category: 'Movies',
      country: 'Bangladesh',
      isLive: true,
      viewers: 6000,
      currentShow: 'Hollywood Movie',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/sonypix_hd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'mt4',
      name: 'Sony MAX 2 (Toffee)',
      category: 'Movies',
      country: 'Bangladesh',
      isLive: true,
      viewers: 5000,
      currentShow: 'Movie',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/sonymax_2/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'mt5',
      name: 'Zee Cinema HD (Toffee)',
      category: 'Movies',
      country: 'Bangladesh',
      isLive: true,
      viewers: 6000,
      currentShow: 'Hindi Movie',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/zee_cinema_hd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'mt6',
      name: 'B4U Movies (Toffee)',
      category: 'Movies',
      country: 'Bangladesh',
      isLive: true,
      viewers: 4000,
      currentShow: 'Bollywood Movie',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/b4u_movies/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'mt7',
      name: '& Pictures HD (Toffee)',
      category: 'Movies',
      country: 'Bangladesh',
      isLive: true,
      viewers: 4000,
      currentShow: 'Hindi Movie',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/andpicture_hd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'mt8',
      name: 'Toffee Movies VIP',
      category: 'Movies',
      country: 'Bangladesh',
      isLive: true,
      viewers: 5000,
      currentShow: 'Movie',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/toffee_movie/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'mt9',
      name: 'Zee Bangla Cinema (Toffee)',
      category: 'Movies',
      country: 'Bangladesh',
      isLive: true,
      viewers: 4000,
      currentShow: 'Bangla Movie',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/zee_bangla_cinema/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),

    // ── Entertainment ─────────────────────────────────────────
    ChannelModel(
      id: 'e1',
      name: 'Sony Aath',
      category: 'Entertainment',
      country: 'India',
      isLive: true,
      viewers: 8700,
      currentShow: 'Entertainment',
      streamUrl: 'http://198.195.239.50:8095/SonyAath/tracks-v1a1/mono.m3u8',
    ),
    ChannelModel(
      id: 'e2',
      name: 'Sony Aath (New)',
      category: 'Entertainment',
      country: 'India',
      isLive: true,
      viewers: 7000,
      currentShow: 'Entertainment',
      streamUrl: 'https://playyonogames.in/sliv/stream.m3u8?id=1000009255',
      headers: {
        'User-Agent': mozillaUA,
        'Referer': 'https://playyonogames.in/',
      },
    ),
    ChannelModel(
      id: 'e3',
      name: 'Toffee Dramas VIP',
      category: 'Entertainment',
      country: 'Bangladesh',
      isLive: true,
      viewers: 5000,
      currentShow: 'Drama',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/toffee_drama/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'e4',
      name: 'Sony Aat VIP (Toffee)',
      category: 'Entertainment',
      country: 'Bangladesh',
      isLive: true,
      viewers: 6000,
      currentShow: 'Entertainment',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/sonyaath/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'e5',
      name: 'B4U Music (Toffee)',
      category: 'Entertainment',
      country: 'Bangladesh',
      isLive: true,
      viewers: 4000,
      currentShow: 'Music',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/b4u_music/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'e6',
      name: 'Zee Bangla (Toffee)',
      category: 'Entertainment',
      country: 'Bangladesh',
      isLive: true,
      viewers: 8000,
      currentShow: 'Bengali Drama',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/zee_bangla/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'e7',
      name: 'Sony Yay',
      category: 'Entertainment',
      country: 'India',
      isLive: true,
      viewers: 3000,
      currentShow: 'Kids Entertainment',
      streamUrl: 'https://playyonogames.in/sliv/stream.m3u8?id=1000001971',
      headers: {
        'User-Agent': mozillaUA,
        'Referer': 'https://playyonogames.in/',
      },
    ),

    // ── Pakistan ──────────────────────────────────────────────
    ChannelModel(
      id: 'p1',
      name: 'Hum TV (Toffee)',
      category: 'Pakistan',
      country: 'Pakistan',
      isLive: true,
      viewers: 8000,
      currentShow: 'Pakistani Drama',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/hum_tv/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'p2',
      name: 'Hum Masala (Toffee)',
      category: 'Pakistan',
      country: 'Pakistan',
      isLive: true,
      viewers: 4000,
      currentShow: 'Pakistani Drama',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/hum_masala/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'p3',
      name: 'Hum Sitarey (Toffee)',
      category: 'Pakistan',
      country: 'Pakistan',
      isLive: true,
      viewers: 3000,
      currentShow: 'Pakistani Entertainment',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/hum_sitaray/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),

    // ── Kids ──────────────────────────────────────────────────
    ChannelModel(
      id: 'k1',
      name: 'Cartoon Network HD (Toffee)',
      category: 'Kids',
      country: 'Bangladesh',
      isLive: true,
      viewers: 5000,
      currentShow: 'Cartoons',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/cartoon_network_hd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'k2',
      name: 'Cartoon Network (Toffee)',
      category: 'Kids',
      country: 'Bangladesh',
      isLive: true,
      viewers: 4000,
      currentShow: 'Cartoons',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/cartoon_network_sd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'k3',
      name: 'Pogo (Toffee)',
      category: 'Kids',
      country: 'Bangladesh',
      isLive: true,
      viewers: 3000,
      currentShow: 'Kids Shows',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/pogo_sd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'k4',
      name: 'Discovery Kids (Toffee)',
      category: 'Kids',
      country: 'Bangladesh',
      isLive: true,
      viewers: 3000,
      currentShow: 'Discovery Kids',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/discovery_kids/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'k5',
      name: 'Sony Yay (Toffee)',
      category: 'Kids',
      country: 'Bangladesh',
      isLive: true,
      viewers: 2000,
      currentShow: 'Kids Shows',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/sonyyay/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),

    // ── English ───────────────────────────────────────────────
    ChannelModel(
      id: 'en1',
      name: 'Al Jazeera',
      category: 'English',
      country: 'Qatar',
      isLive: true,
      viewers: 5500,
      currentShow: 'World News',
      streamUrl: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1721/output/index.m3u8',
    ),
    ChannelModel(
      id: 'en2',
      name: 'CNN (Toffee)',
      category: 'English',
      country: 'USA',
      isLive: true,
      viewers: 6000,
      currentShow: 'World News',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/cnn/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'en3',
      name: 'TLC HD (Toffee)',
      category: 'English',
      country: 'Bangladesh',
      isLive: true,
      viewers: 3000,
      currentShow: 'Documentary',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/tlc_hd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'en4',
      name: 'Animal Planet HD (Toffee)',
      category: 'English',
      country: 'Bangladesh',
      isLive: true,
      viewers: 4000,
      currentShow: 'Nature',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/animal_planet_hd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'en5',
      name: 'Discovery HD (Toffee)',
      category: 'English',
      country: 'Bangladesh',
      isLive: true,
      viewers: 5000,
      currentShow: 'Discovery',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/discovery_hd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'en6',
      name: 'Discovery Science (Toffee)',
      category: 'English',
      country: 'Bangladesh',
      isLive: true,
      viewers: 3000,
      currentShow: 'Science',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/discovery_science/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'en7',
      name: 'Sony BBC Earth (Toffee)',
      category: 'English',
      country: 'Bangladesh',
      isLive: true,
      viewers: 4000,
      currentShow: 'Nature',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/sonybbc_earth_hd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'en8',
      name: 'Investigation Discovery HD (Toffee)',
      category: 'English',
      country: 'Bangladesh',
      isLive: true,
      viewers: 2000,
      currentShow: 'Investigation',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/discovary_investigation_hd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'en9',
      name: 'TLC (Toffee)',
      category: 'English',
      country: 'Bangladesh',
      isLive: true,
      viewers: 2000,
      currentShow: 'Documentary',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/tlc_sd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'en10',
      name: 'Animal Planet (Toffee)',
      category: 'English',
      country: 'Bangladesh',
      isLive: true,
      viewers: 3000,
      currentShow: 'Nature',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/animal_planet_sd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'en11',
      name: 'Discovery (Toffee)',
      category: 'English',
      country: 'Bangladesh',
      isLive: true,
      viewers: 4000,
      currentShow: 'Discovery',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/discovery_sd/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
    ChannelModel(
      id: 'en12',
      name: 'Discovery Turbo (Toffee)',
      category: 'English',
      country: 'Bangladesh',
      isLive: true,
      viewers: 2000,
      currentShow: 'Cars & Speed',
      streamUrl:
          'https://bldcmprod-cdn.toffeelive.com/cdn/live/discovery_turbo/playlist.m3u8',
      headers: {
        'User-Agent': ToffeeHeaders.userAgent,
        'Cookie': ToffeeHeaders.cookieHeader,
        'Referer': 'https://toffeelive.com/',
      },
    ),
  ];

  // ── M3U Parser ────────────────────────────────────────────
  List<ChannelModel> _parseM3U(String content) {
    return M3uMergeParser.parse(
      content,
      mapCategory: _mapCat,
      mapCountry: _mapCtry,
    );
  }

  String _afterComma(String l) {
    final i = l.lastIndexOf(',');
    return i == -1 ? '' : l.substring(i + 1).trim();
  }

  String _attr(String l, String k) =>
      RegExp('$k="([^"]*)"', caseSensitive: false).firstMatch(l)?.group(1) ??
      '';

  String _mapCat(String g, String n) {
    final s = (g + n).toLowerCase();
    if (s.contains('sport') ||
        s.contains('cricket') ||
        s.contains('football') ||
        s.contains('soccer') ||
        s.contains('espn') ||
        s.contains('star sports') ||
        s.contains('sony sports') ||
        s.contains('ptv sports') ||
        s.contains('gazi') ||
        s.contains('willow') ||
        s.contains('fancode') ||
        s.contains('tsports') ||
        s.contains('tennis') ||
        s.contains('nba') ||
        s.contains('ipl') ||
        s.contains('bpl') ||
        s.contains('dd sports') ||
        s.contains('eurosport') ||
        s.contains('geo super') ||
        s.contains('a sports') ||
        s.contains('sports18') ||
        s.contains('nagorik')) return 'Sports';
    if (s.contains('movie') ||
        s.contains('cinema') ||
        s.contains('film') ||
        s.contains('hbo') ||
        s.contains('star gold') ||
        s.contains('zee cinema')) return 'Movies';
    if (s.contains('kids') ||
        s.contains('cartoon') ||
        s.contains('nick') ||
        s.contains('disney') ||
        s.contains('baby')) return 'Kids';
    if (s.contains('korea') ||
        s.contains('kdrama') ||
        s.contains('kbs') ||
        s.contains('mbc') ||
        s.contains('tvn')) return 'KDrama';
    if (s.contains('bangla') ||
        s.contains('bangladesh') ||
        s.contains('ntv') ||
        s.contains('channel i') ||
        s.contains('channel 24') ||
        s.contains('channel 9') ||
        s.contains('rtv') ||
        s.contains('somoy') ||
        s.contains('jamuna') ||
        s.contains('nagorik') ||
        s.contains('news24') ||
        s.contains('news 24') ||
        s.contains('boishakhi') ||
        s.contains('btv') ||
        s.contains('atn') ||
        s.contains('dbc') ||
        s.contains('independent') ||
        s.contains('ekhon') ||
        s.contains('dipto') ||
        s.contains('deepto') ||
        s.contains('maasranga') ||
        s.contains('masranga') ||
        s.contains('bangla vision') ||
        s.contains('71 tv') ||
        s.contains('ekkator')) return 'Bangladesh';
    if (s.contains('hindi') ||
        s.contains('india') ||
        s.contains('zee') ||
        s.contains('colors') ||
        s.contains('star plus') ||
        s.contains('sony') ||
        s.contains('aaj tak') ||
        s.contains('ndtv') ||
        s.contains('republic')) return 'Hindi';
    if (s.contains('pakistan') ||
        s.contains('pak') ||
        s.contains('ary') ||
        s.contains('geo') ||
        s.contains('hum') ||
        s.contains('express') ||
        s.contains('92 news')) return 'Pakistan';
    if (s.contains('english') ||
        s.contains('uk') ||
        s.contains('bbc') ||
        s.contains('cnn') ||
        s.contains('sky') ||
        s.contains('fox') ||
        s.contains('usa') ||
        s.contains('al jazeera')) return 'English';
    return 'Entertainment';
  }

  String _mapCtry(String g, String n) {
    final s = (g + n).toLowerCase();
    if (s.contains('bangladesh') ||
        s.contains('bangla') ||
        s.contains('nagorik') ||
        s.contains('news24')) return 'Bangladesh';
    if (s.contains('pakistan') || s.contains('pak') || s.contains('ptv')) {
      return 'Pakistan';
    }
    if (s.contains('india') || s.contains('hindi')) return 'India';
    if (s.contains('uk') || s.contains('bbc') || s.contains('sky')) return 'UK';
    if (s.contains('usa') || s.contains('espn') || s.contains('willow')) {
      return 'USA';
    }
    if (s.contains('korea') || s.contains('kbs')) return 'Korea';
    return 'International';
  }

  // ── Demo data ─────────────────────────────────────────────
  static final List<MatchModel> _demoLive = [
    MatchModel(
      id: 'm1',
      sport: 'Cricket',
      teamA: 'Bangladesh',
      teamB: 'India',
      scoreA: '187/4',
      scoreB: '162/8',
      status: 'live',
      time: '18.2 Ov',
      channel: 'T Sports',
      streamUrl: 'http://198.195.239.50:8095/Tsports/tracks-v1a1/mono.m3u8',
      matchDate: DateTime.now(),
      winChanceA: 55,
      winChanceB: 35,
      drawChance: 10,
    ),
    MatchModel(
      id: 'm2',
      sport: 'Football',
      teamA: 'Arsenal',
      teamB: 'Chelsea',
      scoreA: '2',
      scoreB: '1',
      status: 'live',
      time: "67'",
      channel: 'Sony Sports',
      streamUrl: '',
      matchDate: DateTime.now(),
      winChanceA: 48,
      winChanceB: 30,
      drawChance: 22,
    ),
    MatchModel(
      id: 'm3',
      sport: 'Basketball',
      teamA: 'Lakers',
      teamB: 'Bulls',
      scoreA: '98',
      scoreB: '91',
      status: 'live',
      time: 'Q3',
      channel: 'ESPN',
      streamUrl: '',
      matchDate: DateTime.now(),
      winChanceA: 61,
      winChanceB: 31,
      drawChance: 8,
    ),
    MatchModel(
      id: 'm4',
      sport: 'Cricket',
      teamA: 'Pakistan',
      teamB: 'SA',
      scoreA: '156/4',
      scoreB: '',
      status: 'live',
      time: '15.3 Ov',
      channel: 'Willow HD',
      streamUrl: 'http://198.195.239.50:8095/WiLLow/index.m3u8',
      matchDate: DateTime.now(),
      winChanceA: 60,
      winChanceB: 40,
      drawChance: 0,
    ),
    MatchModel(
      id: 'm5',
      sport: 'Tennis',
      teamA: 'Djokovic',
      teamB: 'Alcaraz',
      scoreA: '6-4',
      scoreB: '3-6',
      status: 'live',
      time: 'Set 3',
      channel: 'Eurosport',
      streamUrl: '',
      matchDate: DateTime.now(),
      winChanceA: 52,
      winChanceB: 48,
      drawChance: 0,
    ),
  ];

  static final List<MatchModel> _demoToday = [
    ..._demoLive,
    MatchModel(
      id: 'm6',
      sport: 'Cricket',
      teamA: 'Pakistan',
      teamB: 'Sri Lanka',
      scoreA: '',
      scoreB: '',
      status: 'upcoming',
      time: '3:30 PM',
      channel: 'PTV Sports',
      streamUrl: 'http://198.195.239.50:8095/PTV-kutta/video.m3u8',
      matchDate: DateTime.now().add(const Duration(hours: 3)),
      winChanceA: 58,
      winChanceB: 35,
      drawChance: 7,
    ),
    MatchModel(
      id: 'm7',
      sport: 'Football',
      teamA: 'Man City',
      teamB: 'Liverpool',
      scoreA: '',
      scoreB: '',
      status: 'upcoming',
      time: '6:00 PM',
      channel: 'Sony Sports',
      streamUrl: '',
      matchDate: DateTime.now().add(const Duration(hours: 6)),
      winChanceA: 44,
      winChanceB: 38,
      drawChance: 18,
    ),
    MatchModel(
      id: 'm8',
      sport: 'Boxing',
      teamA: 'Fury',
      teamB: 'Usyk',
      scoreA: '',
      scoreB: '',
      status: 'upcoming',
      time: '9:00 PM',
      channel: 'DAZN',
      streamUrl: '',
      matchDate: DateTime.now().add(const Duration(hours: 9)),
      winChanceA: 38,
      winChanceB: 54,
      drawChance: 8,
    ),
  ];

  static final List<MatchModel> _demoUpcoming = [
    MatchModel(
      id: 'u1',
      sport: 'Cricket',
      teamA: 'Bangladesh',
      teamB: 'Australia',
      scoreA: '',
      scoreB: '',
      status: 'upcoming',
      time: '10:00 AM',
      channel: 'T Sports',
      streamUrl: 'http://198.195.239.50:8095/Tsports/tracks-v1a1/mono.m3u8',
      matchDate: DateTime.now().add(const Duration(days: 1)),
      winChanceA: 40,
      winChanceB: 55,
      drawChance: 5,
    ),
    MatchModel(
      id: 'u2',
      sport: 'Football',
      teamA: 'Real Madrid',
      teamB: 'Barcelona',
      scoreA: '',
      scoreB: '',
      status: 'upcoming',
      time: '8:00 PM',
      channel: 'BeIN Sports',
      streamUrl: '',
      matchDate: DateTime.now().add(const Duration(days: 1)),
      winChanceA: 42,
      winChanceB: 38,
      drawChance: 20,
    ),
    MatchModel(
      id: 'u3',
      sport: 'Formula 1',
      teamA: 'Saudi Arabia GP',
      teamB: '',
      scoreA: '',
      scoreB: '',
      status: 'upcoming',
      time: '7:00 PM',
      channel: 'F1 TV',
      streamUrl: '',
      matchDate: DateTime.now().add(const Duration(days: 4)),
      winChanceA: 0,
      winChanceB: 0,
      drawChance: 0,
    ),
    MatchModel(
      id: 'u4',
      sport: 'Tennis',
      teamA: 'Wimbledon',
      teamB: 'Qualifiers',
      scoreA: '',
      scoreB: '',
      status: 'upcoming',
      time: 'All Day',
      channel: 'Eurosport',
      streamUrl: '',
      matchDate: DateTime.now().add(const Duration(days: 7)),
      winChanceA: 0,
      winChanceB: 0,
      drawChance: 0,
    ),
  ];

  static final List<NewsModel> _demoNews = [
    NewsModel(
      id: 'n1',
      title: 'Bangladesh stun India with record T20 chase',
      category: 'Cricket',
      source: 'Cricbuzz',
      publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    NewsModel(
      id: 'n2',
      title: 'Arsenal go top of Premier League after Chelsea win',
      category: 'Football',
      source: 'BBC Sport',
      publishedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    NewsModel(
      id: 'n3',
      title: 'Verstappen leads Bahrain GP from pole position',
      category: 'Formula 1',
      source: 'F1.com',
      publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    NewsModel(
      id: 'n4',
      title: 'Usyk vs Fury 2: Who has the edge tonight?',
      category: 'Boxing',
      source: 'ESPN',
      publishedAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    NewsModel(
      id: 'n5',
      title: 'Lakers hold off Bulls in overtime classic',
      category: 'Basketball',
      source: 'ESPN',
      publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];
}
