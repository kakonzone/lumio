import 'dart:async';
import 'package:flutter/material.dart';
import '../models/model.dart';
import '../models/live_event_match.dart';
import '../services/footystream_service.dart';
import '../services/live_events_service.dart';
import '../services/news_service.dart';
import '../services/score_service.dart';
import '../services/stream_health_service.dart';
import '../utils/live_event_sort.dart';
import '../utils/schedule_merge.dart';
import '../utils/match_grouping.dart';
import '../utils/debug_log.dart';
import '../utils/channel_hub_processor.dart';
import '../config/channel_categories.dart';
import '../utils/priority_broadcasters.dart';
import '../services/catalog_service.dart';
import '../services/featured_live_events_service.dart';
import '../services/featured_live_events_cache.dart';
import 'user_state_provider.dart';

class AppProvider extends ChangeNotifier {
  AppProvider(this.userState) {
    userState.addListener(notifyListeners);
  }

  final UserStateProvider userState;

  // Main catalog: your GitHub playlist only ([CatalogService] / loadAppCatalogChannels).

  int get favoriteCount => userState.favoriteCount;

  bool isFavorite(String channelId) => userState.isFavorite(channelId);

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
    final list =
        _channels.where((c) => userState.isFavorite(c.id)).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<void> loadFavorites() => userState.loadFavorites();

  Future<void> addFavorite(ChannelModel channel) async {
    await userState.addFavoriteId(channel.id);
  }

  Future<void> removeFavorite(String channelId) async {
    await userState.removeFavoriteId(channelId);
  }

  // ── Theme (delegated) ─────────────────────────────────────
  bool get isDark => userState.isDark;

  void toggleTheme() => userState.toggleTheme();

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
  List<LiveEventMatch> _liveEventAll = [];
  bool _liveEventsLoading = false;
  DateTime? _liveEventsLoadedAt;
  static const _liveEventsTtl = Duration(minutes: 5);
  List<LiveEventMatch> _featuredLiveEvents = [];
  String _featuredSectionTitle = 'World Cup 2026';
  String _featuredSectionSubtitle = '';
  bool _featuredLiveEventsLoading = false;
  Map<String, bool> _streamHealth = {};
  final Map<String, bool> _streamUrlHealth = {};
  final Set<String> _pendingStreamUrlChecks = {};
  final Map<String, DateTime> _streamHealthAt = {};
  bool _streamHealthLoading = false;
  final Set<String> _pendingStreamHealthIds = {};
  final List<String> _streamHealthQueue = [];
  bool _streamHealthWorkerActive = false;
  static const _streamHealthTtl = Duration(minutes: 10);
  static const _healthBatchSize = 3;
  DateTime? _lastStreamHealthNotify;
  final Set<String> _streamHealthPriorityIds = {};
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
  List<LiveEventMatch> get featuredLiveEvents => _featuredLiveEvents;
  String get featuredLiveEventsSectionTitle => _featuredSectionTitle;
  String get featuredLiveEventsSectionSubtitle => _featuredSectionSubtitle;
  bool get featuredLiveEventsLoading => _featuredLiveEventsLoading;
  bool get hasFeaturedLiveEventsData => _featuredLiveEvents.isNotEmpty;
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
    _streamHealthPriorityIds.clear();
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
        _streamHealthPriorityIds.add(c.id);
        _streamHealthQueue.insert(0, c.id);
      } else {
        _streamHealthPriorityIds.remove(c.id);
        if (!_streamHealthQueue.contains(c.id)) {
          _streamHealthQueue.add(c.id);
        }
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
        final useLongTimeout = batch.any(_streamHealthPriorityIds.contains);
        for (final c in batch) {
          _streamHealthPriorityIds.remove(c.id);
        }
        try {
          final partial = await StreamHealthService.checkChannels(
            batch,
            timeout: useLongTimeout
                ? const Duration(seconds: 5)
                : const Duration(seconds: 2),
          );
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
        _notifyStreamHealthThrottled();
      }

      for (final id in batchIds) {
        _pendingStreamHealthIds.remove(id);
      }
    }

    _streamHealthWorkerActive = false;
    _streamHealthLoading =
        _pendingStreamHealthIds.isNotEmpty || _streamHealthQueue.isNotEmpty;
    _notifyStreamHealthThrottled(force: true);
  }

  void _notifyStreamHealthThrottled({bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        _lastStreamHealthNotify != null &&
        now.difference(_lastStreamHealthNotify!) <
            const Duration(milliseconds: 400)) {
      return;
    }
    _lastStreamHealthNotify = now;
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
    await loadChannels(forceRefresh: true);
    await loadNews();
  }

  Timer? _catalogFollowUpTimer;

  bool get isCatalogSyncing => _channelsLoading;

  String get channelCountLabel => '${_liveChannels.length}';

  /// Called by main.dart via AppProvider()..init()
  Future<void> init() async {
    await loadFavorites();
    unawaited(loadNews());
    await loadChannels();
  }

  static const specialLinkCategoryId = ChannelCategoryRegistry.specialLinkId;

  /// Dynamic categories from your GitHub playlist (counts per genre).
  List<Map<String, String>> get homeCategoryTiles =>
      ChannelCategoryRegistry.homeTilesForChannels(_channels);

  @Deprecated('Use homeCategoryTiles')
  static const homeCategories = <Map<String, String>>[
    {'icon': '⚽', 'label': 'Sports', 'cat': 'Sports'},
    {'icon': '🇧🇩', 'label': 'Bangla', 'cat': 'Bangladesh'},
    {'icon': '🔗', 'label': 'Special Link', 'cat': '__special_link__'},
  ];

  // ── Matches ───────────────────────────────────────────────
  Future<void> loadMatches() async {
    _matchesLoading = true;
    _matchesError = null;
    notifyListeners();
    try {
      final footyTodayFuture = FootyStreamService.fetchToday();
      _scoreGroups = await ScoreService.fetchTodayScoreboards();
      final footyToday = await footyTodayFuture;
      final espnToday = _scoreGroups.expand((g) => g.matches).toList();

      final mergedToday = ScheduleMerge.mergeMatches([
        footyToday,
        espnToday,
      ]);

      if (mergedToday.isNotEmpty) {
        final attached = mergedToday.map(_attachStreamToMatch).toList();
        _todayMatches = attached;
        _liveMatches = attached.where((m) => m.status == 'live').toList();
        _upcomingMatches =
            attached.where((m) => m.status == 'upcoming').toList();
        _predictions = attached.take(6).toList();
      } else {
        final fetched = espnToday.map(_attachStreamToMatch).toList();

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
      }
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

  // ── Channels (GitHub playlist only) ───────────────────────
  Future<void> loadChannels({bool forceRefresh = false}) async {
    final showLoadingSpinner = _channels.isEmpty;
    if (showLoadingSpinner) {
      _channelsLoading = true;
      _channelsError = null;
      notifyListeners();
    }

    final catalog = await CatalogService.instance.loadCatalog(
      forceRefresh: forceRefresh,
    );
    if (catalog.errorMessage != null) {
      _channelsError = catalog.errorMessage;
    }

    _applyChannelCatalog(catalog.channels);
  }

  void _applyChannelCatalog(List<ChannelModel> raw) {
    final upgraded = _upgradeHttpStreamsWithFallback(raw);
    _channels = upgraded;
    _liveChannels = upgraded.where((c) => c.streamUrl.isNotEmpty).toList();
    _channelsLoading = false;
    notifyListeners();
    _scheduleCatalogFollowUp();
  }

  void _scheduleCatalogFollowUp() {
    _catalogFollowUpTimer?.cancel();
    _catalogFollowUpTimer = Timer(const Duration(milliseconds: 900), () {
      if (_channels.isEmpty) return;
      unawaited(loadLiveEvents());
      unawaited(loadFeaturedLiveEvents());
      _scheduleGlobalStreamHealthScan();
    });
  }

  /// Prefer HTTPS for HTTP primary URLs; player retries HTTP in background if needed.
  List<ChannelModel> _upgradeHttpStreamsWithFallback(List<ChannelModel> channels) {
    return channels.map((ch) {
      final primary = ch.streamUrl;
      if (!primary.startsWith('http://')) return ch;
      return ch.copyWith(
        streamUrl: primary.replaceFirst('http://', 'https://'),
      );
    }).toList();
  }

  // ── Refresh ───────────────────────────────────────────────
  Future<void> refresh() async {
    ScoreService.clearCache();
    FootyStreamService.clearCache();
    final reloadScores = _scoresRequested;
    _clearStreamHealthCache();
    _liveEventFootball = [];
    _liveEventCricket = [];
    _liveEventAll = [];
    _liveEventsLoadedAt = null;
    _featuredLiveEvents = [];
    _scoresRequested = false;
    await FeaturedLiveEventsCache.instance.clear();
    await loadChannels(forceRefresh: true);
    await loadNews();
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
    final normalized = ChannelCategoryRegistry.normalizeId(cat);
    return _channels
        .where((c) => ChannelCategoryRegistry.normalizeId(c.category) == normalized)
        .toList();
  }

  /// Categories tab rows — only genres that have channels (+ Special Link).
  List<List<Object>> get categoriesGenreRows =>
      ChannelCategoryRegistry.genreRowsForChannels(_channels);

  bool get hasLiveEventsData =>
      _liveEventAll.isNotEmpty ||
      _liveEventFootball.isNotEmpty ||
      _liveEventCricket.isNotEmpty;

  /// Cached live events — skips network if data is fresh unless [force].
  Future<void> loadFeaturedLiveEvents({bool force = false}) async {
    if (!hasFeaturedLiveEventsData) {
      _featuredLiveEventsLoading = true;
      notifyListeners();
    }

    try {
      final payload = await FeaturedLiveEventsService.instance.load(
        forceRefresh: force,
      );
      _featuredLiveEvents = payload.events;
      _featuredSectionTitle = payload.sectionTitle;
      _featuredSectionSubtitle = payload.sectionSubtitle;
    } catch (_) {
      if (!hasFeaturedLiveEventsData) {
        _featuredLiveEvents = [];
      }
    } finally {
      _featuredLiveEventsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLiveEvents({bool force = false}) async {
    if (_channels.isEmpty) return;

    final cacheFresh = _liveEventsLoadedAt != null &&
        DateTime.now().difference(_liveEventsLoadedAt!) < _liveEventsTtl;
    if (!force && hasLiveEventsData && cacheFresh) {
      agentDebugLog(
        location: 'app_provider.dart:loadLiveEvents',
        message: 'cache hit — skip fetch',
        hypothesisId: 'H2',
      );
      return;
    }

    final loadStart = DateTime.now().millisecondsSinceEpoch;
    agentDebugLog(
      location: 'app_provider.dart:loadLiveEvents',
      message: 'fetch start',
      hypothesisId: 'H2',
      data: {'force': force, 'hadCache': hasLiveEventsData},
    );

    if (!hasLiveEventsData) {
      _liveEventsLoading = true;
      notifyListeners();
    }

    try {
      final bundle = await LiveEventsService.fetch(_channels);
      _liveEventAll = bundle.all;
      _liveEventFootball = bundle.football;
      _liveEventCricket = bundle.cricket;
      _liveEventsLoadedAt = DateTime.now();
    } catch (_) {
      if (!hasLiveEventsData) {
        _liveEventFootball = [];
        _liveEventCricket = [];
        _liveEventAll = [];
      }
    } finally {
      _liveEventsLoading = false;
      notifyListeners();
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
    }
  }

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

  List<MatchModel> get internationalScoreMatches =>
      MatchGrouping.international(scoreCardMatches);

  List<MatchModel> get premierLeagueScoreMatches =>
      MatchGrouping.premierLeague(scoreCardMatches);

  List<LiveEventMatch> get sortedLiveEvents {
    if (_liveEventAll.isNotEmpty) return _liveEventAll;
    return LiveEventSort.sort([
      ..._liveEventFootball,
      ..._liveEventCricket,
    ]);
  }

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
    'fifa',
    'world cup',
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
    'fifa',
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
    final pool = _channels
        .where((c) => c.category == 'Sports' && c.streamUrl.isNotEmpty)
        .toList();
    pool.sort(PriorityBroadcasters.compare);

    final out = <ChannelModel>[];
    for (final c in pool) {
      final name = c.name.toLowerCase();
      if (keywords.any(name.contains)) {
        out.add(c);
      }
      if (out.length >= limit) break;
    }
    if (out.length < limit) {
      for (final c in pool) {
        if (out.any((x) => x.id == c.id)) continue;
        out.add(c);
        if (out.length >= limit) break;
      }
    }
    return out;
  }

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
    final counts = <String, int>{};
    for (final c in _channels) {
      if (c.streamUrl.isEmpty) continue;
      final id = ChannelCategoryRegistry.normalizeId(c.category);
      counts[id] = (counts[id] ?? 0) + 1;
    }
    final cats = counts.keys.toList();
    cats.sort((a, b) {
      final da = ChannelCategoryRegistry.defFor(a)?.sortOrder ?? 50;
      final db = ChannelCategoryRegistry.defFor(b)?.sortOrder ?? 50;
      final cmp = da.compareTo(db);
      if (cmp != 0) return cmp;
      return (counts[b] ?? 0).compareTo(counts[a] ?? 0);
    });
    return ['All', ...cats];
  }

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

  // ── Demo data (scores/news fallback only — no channel URLs) ──
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
      streamUrl: '',
      matchDate: DateTime.now(),
      winChanceA: 55,
      winChanceB: 35,
      drawChance: 10,
    ),
  ];

  static final List<MatchModel> _demoToday = [..._demoLive];

  static final List<MatchModel> _demoUpcoming = const [];

  static final List<NewsModel> _demoNews = [
    NewsModel(
      id: 'n1',
      title: 'Bangladesh stun India with record T20 chase',
      category: 'Cricket',
      source: 'Cricbuzz',
      publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];
}
