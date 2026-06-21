import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/logging/safe_logger.dart';
import '../models/model.dart';
import '../models/score_state.dart';
import '../models/live_event_match.dart';
import '../services/footystream_service.dart';
import '../services/live_events_service.dart';
import '../services/news_service.dart';
import '../services/score_service.dart';
import '../utils/live_event_sort.dart';
import '../utils/schedule_merge.dart';
import '../utils/match_grouping.dart';
import '../services/featured_live_events_service.dart';
import '../services/featured_live_events_cache.dart';
import 'user_state_provider.dart';
import 'channel_catalog_provider.dart';
import 'ui_state_provider.dart';

/// Facade over [UserStateProvider], [UiStateProvider], and [ChannelCatalogProvider].
class AppProvider extends ChangeNotifier {
  AppProvider(
    this.userState, {
    ChannelCatalogProvider? catalogIn,
    UiStateProvider? uiIn,
  })  : catalog = catalogIn ?? ChannelCatalogProvider(),
        ui = uiIn ?? UiStateProvider() {
    userState.addListener(notifyListeners);
    catalog.addListener(notifyListeners);
    ui.addListener(notifyListeners);
    catalog.onCatalogFollowUp = _runCatalogFollowUp;
  }

  final UserStateProvider userState;
  final ChannelCatalogProvider catalog;
  final UiStateProvider ui;

  // ── Favorites / theme (delegated) ─────────────────────────
  int get favoriteCount => userState.favoriteCount;
  bool isFavorite(String channelId) => userState.isFavorite(channelId);
  List<ChannelModel> get favoriteChannels {
    final list =
        catalog.channels.where((c) => userState.isFavorite(c.id)).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<void> loadFavorites() => userState.loadFavorites();
  Future<void> addFavorite(ChannelModel channel) async =>
      userState.addFavoriteId(channel.id);
  Future<void> removeFavorite(String channelId) async =>
      userState.removeFavoriteId(channelId);
  bool get isDark => userState.isDark;
  void toggleTheme() => userState.toggleTheme();

  // ── UI state (delegated) ──────────────────────────────────
  String? get pendingChannelTapId => ui.pendingChannelTapId;
  bool isPendingChannelTap(String channelKey) =>
      ui.isPendingChannelTap(channelKey);
  bool isPendingChannelTapChannel(ChannelModel channel) =>
      ui.isPendingChannelTapChannel(channel);
  void setPendingChannelTap(String? channelId) =>
      ui.setPendingChannelTap(channelId);
  bool isPendingNewsArticle(String articleId) =>
      ui.isPendingNewsArticle(articleId);
  void setPendingNewsArticle(String? articleId) =>
      ui.setPendingNewsArticle(articleId);

  // ── Catalog (delegated) ───────────────────────────────────
  List<ChannelModel> get channels => catalog.channels;
  List<ChannelModel> get gitunChannels => catalog.gitunChannels;
  List<ChannelModel> get liveChannels => catalog.liveChannels;
  bool get channelsLoading => catalog.channelsLoading;
  bool get catalogFromStaleCache => catalog.catalogFromStaleCache;
  String? get channelsError => catalog.channelsError;
  bool get hasChannelsError => catalog.hasChannelsError;
  bool get isCatalogSyncing => catalog.isCatalogSyncing;
  String get channelCountLabel => catalog.channelCountLabel;
  List<ChannelModel> get liveTabChannels => catalog.liveTabChannels;
  List<Map<String, String>> get homeCategoryTiles => catalog.homeCategoryTiles;
  static const specialLinkCategoryId =
      ChannelCatalogProvider.specialLinkCategoryId;
  @Deprecated('Use homeCategoryTiles')
  static const homeCategories = ChannelCatalogProvider.homeCategories;
  List<ChannelModel> get sportsBrowseChannels => catalog.sportsBrowseChannels;
  bool get streamHealthLoading => catalog.streamHealthLoading;
  bool isStreamLive(ChannelModel channel) => catalog.isStreamLive(channel);
  bool isStreamHealthPending(ChannelModel channel) =>
      catalog.isStreamHealthPending(channel);
  bool hasStreamHealthResult(ChannelModel channel) =>
      catalog.hasStreamHealthResult(channel);
  bool isStreamUrlLive(String url) => catalog.isStreamUrlLive(url);
  bool isStreamUrlHealthPending(String url) =>
      catalog.isStreamUrlHealthPending(url);
  bool hasStreamUrlHealthResult(String url) =>
      catalog.hasStreamUrlHealthResult(url);
  List<ChannelModel> playerRelatedChannels({
    required String currentTitle,
    String? currentUrl,
    required String relatedCategory,
    List<ChannelModel>? fallback,
  }) =>
      catalog.playerRelatedChannels(
        currentTitle: currentTitle,
        currentUrl: currentUrl,
        relatedCategory: relatedCategory,
        fallback: fallback,
      );
  void setGitunChannels(List<ChannelModel> channels) =>
      catalog.setGitunChannels(channels);
  Future<void> ensureGitunChannelsLoaded({bool forceRefresh = false}) =>
      catalog.ensureGitunChannelsLoaded(forceRefresh: forceRefresh);
  Future<void> preloadGitunChannelsFromCache() =>
      catalog.preloadGitunChannelsFromCache();
  List<ChannelModel> liveNavTopSportsChannels() =>
      catalog.liveNavTopSportsChannels();
  List<StreamLink> playbackLinksFor(ChannelModel channel) =>
      catalog.playbackLinksFor(channel);
  bool hasMultiplePlaybackLinks(ChannelModel channel) =>
      catalog.hasMultiplePlaybackLinks(channel);
  List<ChannelModel> gitunRelatedChannels({
    required String currentTitle,
    String? currentUrl,
    int limit = 12,
  }) =>
      catalog.gitunRelatedChannels(
        currentTitle: currentTitle,
        currentUrl: currentUrl,
        limit: limit,
      );
  Future<void> ensureStreamHealth(
    Iterable<ChannelModel> channels, {
    bool priority = false,
    bool force = false,
  }) =>
      catalog.ensureStreamHealth(channels, priority: priority, force: force);
  Future<void> checkStreamHealthFor(
    Iterable<ChannelModel> channels, {
    bool force = false,
  }) =>
      catalog.checkStreamHealthFor(channels, force: force);
  Future<void> loadChannels({bool forceRefresh = false}) =>
      catalog.loadChannels(forceRefresh: forceRefresh);
  void onLiveTabSelected() => catalog.onLiveTabSelected();
  List<ChannelModel> search(String q) => catalog.search(q);
  List<ChannelModel> byCategory(String cat) => catalog.byCategory(cat);
  List<List<Object>> get categoriesGenreRows => catalog.categoriesGenreRows;
  List<String> get categories => catalog.categories;
  Future<bool> checkChannelActiveNow(ChannelModel channel) =>
      catalog.checkChannelActiveNow(channel);
  Future<bool> checkStreamUrlActiveNow(
    StreamLink link, {
    ChannelModel? channel,
  }) =>
      catalog.checkStreamUrlActiveNow(link, channel: channel);
  ChannelModel? channelForStream(String url) => catalog.channelForStream(url);
  ChannelModel? findChannel({String? id, String? name}) =>
      catalog.findChannel(id: id, name: name);
  List<ChannelModel> recommendedChannels({
    String? excludeStreamUrl,
    String? category,
  }) =>
      catalog.recommendedChannels(
        excludeStreamUrl: excludeStreamUrl,
        category: category,
      );
  String categoryForRelated(ChannelModel channel, {String? browseCategory}) =>
      catalog.categoryForRelated(channel, browseCategory: browseCategory);
  static String relatedSectionLabel(String? category) =>
      ChannelCatalogProvider.relatedSectionLabel(category);

  List<MatchModel> _liveMatches = [];
  List<MatchModel> _todayMatches = [];
  List<MatchModel> _upcomingMatches = [];
  List<MatchModel> _predictions = [];
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
  FeaturedLiveEventsSource _featuredLiveEventsSource =
      FeaturedLiveEventsSource.empty;
  String? _featuredLiveEventsRemoteUpdatedAt;
  String? _featuredLiveEventsError;

  List<MatchModel> get liveMatches => _liveMatches;
  List<MatchModel> get todayMatches => _todayMatches;
  List<MatchModel> get upcomingMatches => _upcomingMatches;
  List<MatchModel> get predictions => _predictions;
  List<NewsModel> get news => _news;
  List<ScoreTournamentGroup> get scoreTournamentGroups => _scoreGroups;
  List<LiveEventMatch> get liveEventFootball => _liveEventFootball;
  List<LiveEventMatch> get liveEventCricket => _liveEventCricket;
  bool get liveEventsLoading => _liveEventsLoading;
  bool get hasLiveEventsData =>
      _liveEventAll.isNotEmpty ||
      _liveEventFootball.isNotEmpty ||
      _liveEventCricket.isNotEmpty;
  List<LiveEventMatch> get featuredLiveEvents => _featuredLiveEvents;
  String get featuredLiveEventsSectionTitle => _featuredSectionTitle;
  String get featuredLiveEventsSectionSubtitle => _featuredSectionSubtitle;
  bool get featuredLiveEventsLoading => _featuredLiveEventsLoading;
  bool get hasFeaturedLiveEventsData => _featuredLiveEvents.isNotEmpty;
  FeaturedLiveEventsSource get featuredLiveEventsSource =>
      _featuredLiveEventsSource;
  String? get featuredLiveEventsRemoteUpdatedAt =>
      _featuredLiveEventsRemoteUpdatedAt;
  String? get featuredLiveEventsError => _featuredLiveEventsError;
  bool get featuredLiveEventsFromAppwrite =>
      _featuredLiveEventsSource == FeaturedLiveEventsSource.appwrite;

  /// Shown only when featured events failed to load (no Appwrite/cache hints).
  String get featuredLiveEventsStatusLine {
    if (_featuredLiveEventsError != null &&
        _featuredLiveEventsError!.trim().isNotEmpty) {
      return _featuredLiveEventsError!;
    }
    return '';
  }

  bool _matchesLoading = false;
  bool _newsLoading = false;
  String? _matchesError;
  String? _newsError;
  ScoreState _scoreState = const ScoreInitial();
  bool _scoresRequested = false;

  bool get matchesLoading => _matchesLoading;
  bool get newsLoading => _newsLoading;
  String? get matchesError => _matchesError;
  String? get newsError => _newsError;
  bool get hasMatchesError => _matchesError != null;
  bool get scoresRequested => _scoresRequested;
  ScoreState get scoreState => _scoreState;

  /// Lazy-load ESPN/Cricbuzz scores (News tab) — avoids blocking Home startup.
  Future<void> ensureMatchesLoaded() async {
    if (_matchesLoading) return;
    if (scoresRequested && _scoreGroups.isNotEmpty) return;
    _scoresRequested = true;
    await loadMatches();
  }

  /// Retry loading matches after error - for user-triggered retry.
  Future<void> retryLoadMatches() async {
    if (_matchesLoading) return;
    ScoreService.clearCache();
    await loadMatches();
  }

  Future<void> ensureHomeContent() async {
    if (catalog.channels.isEmpty) {
      await catalog.loadChannels();
    }
    if (!hasFeaturedLiveEventsData) {
      await loadFeaturedLiveEvents();
    }
  }

  @Deprecated('Use ensureHomeContent — avoids duplicate Appwrite catalog fetch')
  Future<void> loadAll() => ensureHomeContent();

  Future<void> init() async {
    await loadFavorites();
    try {
      await Future.wait([
        loadNews(),
        loadFeaturedLiveEvents(),
        catalog.bootstrapCatalog(),
      ]);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AppProvider] init parallel load failed: $e\n$st');
      }
    }
  }

  Future<void> _runCatalogFollowUp() async {
    try {
      await Future.wait([
        loadFeaturedLiveEvents(),
        loadLiveEvents(),
      ]);
      if (!_scoresRequested) {
        await ensureMatchesLoaded();
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AppProvider] catalog follow-up failed: $e\n$st');
      }
    }
  }

  // ── Matches ───────────────────────────────────────────────
  Future<void> loadMatches() async {
    _matchesLoading = true;
    _matchesError = null;
    _scoreState = const ScoreLoading();
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
        
        _scoreState = ScoreLoaded(
          liveMatches: _liveMatches,
          todayMatches: _todayMatches,
          upcomingMatches: _upcomingMatches,
          predictions: _predictions,
          loadedAt: DateTime.now(),
        );
      } else {
        final fetched = espnToday.map(_attachStreamToMatch).toList();

        if (fetched.isNotEmpty) {
          _liveMatches = fetched;
          _predictions = fetched.take(6).toList();
          _scoreState = ScoreLoaded(
            liveMatches: _liveMatches,
            todayMatches: _liveMatches,
            upcomingMatches: const [],
            predictions: _predictions,
            loadedAt: DateTime.now(),
          );
        } else {
          // No live matches - honest empty state
          _liveMatches = const [];
          _todayMatches = const [];
          _upcomingMatches = const [];
          _predictions = const [];
          _scoreState = ScoreEmpty(checkedAt: DateTime.now());
        }
      }
    } catch (e) {
      _matchesError = e.toString();
      
      // Determine error type for honest error state
      final now = DateTime.now();
      if (e is SocketException) {
        _scoreState = ScoreNetworkError(
          message: 'No internet connection',
          failedAt: now,
        );
      } else if (e.toString().contains('timeout') || e.toString().contains('TimeoutException')) {
        _scoreState = ScoreTimeoutError(
          timeout: const Duration(seconds: 8),
          failedAt: now,
        );
      } else if (e.toString().contains('404') || e.toString().contains('403') || e.toString().contains('401')) {
        _scoreState = ScoreApiError(
          message: 'API unavailable',
          statusCode: 404,
          failedAt: now,
        );
      } else if (e.toString().contains('500') || e.toString().contains('502') || e.toString().contains('503')) {
        _scoreState = ScoreApiError(
          message: 'Server error',
          statusCode: 500,
          failedAt: now,
        );
      } else if (e.toString().contains('FormatException') || e.toString().contains('parse')) {
        _scoreState = ScoreParseError(
          message: 'Invalid response format',
          failedAt: now,
        );
      } else {
        _scoreState = ScoreUnknownError(
          message: e.toString(),
          failedAt: now,
        );
      }
      
      // Clear match data on error
      _liveMatches = const [];
      _todayMatches = const [];
      _upcomingMatches = const [];
      _predictions = const [];
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
      _news = fetched; // No demo fallback - honest empty state
    } catch (e) {
      _newsError = e.toString();
      _news = const []; // Empty on error - no fake news
    } finally {
      _newsLoading = false;
      notifyListeners();
    }
  }

  /// Cached live events — skips network if data is fresh unless [force].
  Future<void> loadFeaturedLiveEvents({bool force = false}) async {
    if (!hasFeaturedLiveEventsData) {
      _featuredLiveEventsLoading = true;
      notifyListeners();
    }

    try {
      final result = await FeaturedLiveEventsService.instance.load(
        forceRefresh: force,
      );
      _featuredLiveEvents = result.payload.events;
      _featuredSectionTitle = result.payload.sectionTitle;
      _featuredSectionSubtitle = result.payload.sectionSubtitle;
      _featuredLiveEventsSource = result.source;
      _featuredLiveEventsRemoteUpdatedAt = result.remoteUpdatedAt;
      _featuredLiveEventsError = result.errorMessage;
    } catch (e) {
      if (!hasFeaturedLiveEventsData) {
        _featuredLiveEvents = [];
        _featuredLiveEventsSource = FeaturedLiveEventsSource.empty;
      }
      _featuredLiveEventsError = e.toString();
    } finally {
      _featuredLiveEventsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLiveEvents({bool force = false}) async {
    if (catalog.channels.isEmpty) return;

    final cacheFresh = _liveEventsLoadedAt != null &&
        DateTime.now().difference(_liveEventsLoadedAt!) < _liveEventsTtl;
    if (!force && hasLiveEventsData && cacheFresh) {
      SafeLogger.debug('provider', 'app_provider.dart:loadLiveEvents: cache hit — skip fetch (H2)');
      return;
    }

    final loadStart = DateTime.now().millisecondsSinceEpoch;
    SafeLogger.debug('provider', 'app_provider.dart:loadLiveEvents: fetch start (H2) force=$force hadCache=$hasLiveEventsData');

    if (!hasLiveEventsData) {
      _liveEventsLoading = true;
      notifyListeners();
    }

    try {
      final bundle = await LiveEventsService.fetch(catalog.channels);
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
      SafeLogger.debug('provider', 'app_provider.dart:loadLiveEvents: fetch done (H2) ms=${DateTime.now().millisecondsSinceEpoch - loadStart} football=${_liveEventFootball.length} cricket=${_liveEventCricket.length}');
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

  MatchModel _attachStreamToMatch(MatchModel m) {
    if (m.streamUrl.isNotEmpty) return m;
    final sport = m.sport.toLowerCase();
    final keywords = sport.contains('foot') || sport.contains('soccer')
        ? _footballKeywords
        : _cricketKeywords;
    final ch = catalog.pickSportsChannelsForMatch(keywords, limit: 1);
    if (ch.isEmpty) return m;
    return m.copyWith(
      streamUrl: ch.first.streamUrl,
      channel: ch.first.name,
    );
  }

  Future<void> refresh() async {
    ScoreService.clearCache();
    FootyStreamService.clearCache();
    final reloadScores = _scoresRequested;
    catalog.clearStreamHealthOnRefresh();
    _liveEventFootball = [];
    _liveEventCricket = [];
    _liveEventAll = [];
    _liveEventsLoadedAt = null;
    _featuredLiveEvents = [];
    _scoresRequested = false;
    await FeaturedLiveEventsCache.instance.clear();
    await catalog.loadChannels(forceRefresh: true);
    await loadFeaturedLiveEvents(force: true);
    await loadNews();
    if (reloadScores) {
      _scoresRequested = true;
      await loadMatches();
    }
  }

  @override
  void dispose() {
    userState.removeListener(notifyListeners);
    catalog.removeListener(notifyListeners);
    ui.removeListener(notifyListeners);
    super.dispose();
  }

  // ── Demo data removed — no fake scores/news in production ──
}
