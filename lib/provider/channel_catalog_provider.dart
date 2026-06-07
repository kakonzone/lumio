import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/model.dart';
import '../config/channel_categories.dart';
import '../config/special_link_config.dart';
import '../services/catalog_service.dart';
import '../services/special_link/gitun_playlist_service.dart';
import '../services/special_link/special_link_cache.dart';
import '../services/stream_health_service.dart';
import '../utils/channel_hub_processor.dart';
import '../utils/channel_playback_links.dart';
import '../utils/priority_broadcasters.dart';
import '../utils/live_nav_top_sports.dart';
import '../utils/sport_channel_icons.dart';
import '../utils/live_tab_channels.dart';
import '../utils/sports_channel_priority.dart';
/// Appwrite catalog, offline cache, GITUN, and stream health probes.
class ChannelCatalogProvider extends ChangeNotifier {
  /// Invoked after catalog is applied (home extras: featured, live events, GITUN).
  Future<void> Function()? onCatalogFollowUp;

  List<ChannelModel> _channels = [];
  List<ChannelModel> _gitunChannels = [];
  List<ChannelModel> _liveChannels = [];
  Map<String, List<ChannelModel>>? _byCategoryIndex;
  List<ChannelModel>? _sportsBrowseCache;
  Map<String, bool> _streamHealth = {};
  final Map<String, bool> _streamUrlHealth = {};
  final Set<String> _pendingStreamUrlChecks = {};
  final Map<String, DateTime> _streamHealthAt = {};
  bool _streamHealthLoading = false;
  final Set<String> _pendingStreamHealthIds = {};
  final Set<String> _streamHealthQueuedIds = {};
  final List<String> _streamHealthQueue = [];
  bool _streamHealthWorkerActive = false;
  static const _streamHealthTtl = Duration(minutes: 10);
  static const _healthBatchSize = 3;
  DateTime? _lastStreamHealthNotify;
  final Set<String> _streamHealthPriorityIds = {};
  static const _globalScanCap = 48;
  static const _sportsHealthScanCap = 72;

  bool _streamHealthScanScheduled = false;
  List<ChannelModel> get channels => _channels;
  List<ChannelModel> get gitunChannels => _gitunChannels;
  List<ChannelModel> get liveChannels => _liveChannels;
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
    if (isGitunBrowseCategory(relatedCategory)) {
      final gitun = gitunRelatedChannels(
        currentTitle: currentTitle,
        currentUrl: currentUrl,
      );
      if (gitun.isNotEmpty) return gitun;
      return fallback ?? const [];
    }

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

  static bool isGitunBrowseCategory(String? category) {
    if (category == null || category.isEmpty) return false;
    final c = category.trim().toUpperCase();
    return c == 'GITUN' ||
        c == SpecialLinkConfig.gitunTitle.toUpperCase() ||
        c == ChannelCategoryRegistry.specialLinkId.toUpperCase();
  }

  void setGitunChannels(List<ChannelModel> channels) {
    _gitunChannels = PriorityBroadcasters.sort(channels);
    notifyListeners();
  }

  /// Loads GITUN playlists (cache first) for Special Link + player recommendations.
  Future<void> ensureGitunChannelsLoaded({bool forceRefresh = false}) async {
    if (!forceRefresh && _gitunChannels.isNotEmpty) return;

    if (!forceRefresh) {
      final cached = await SpecialLinkCache.instance.readGitunChannels();
      if (cached != null && cached.isNotEmpty) {
        _gitunChannels = PriorityBroadcasters.sort(cached);
        notifyListeners();
        return;
      }
    }

    final list = await GitunPlaylistService.instance.loadGitunChannels(
      forceRefresh: forceRefresh,
    );
    _gitunChannels = PriorityBroadcasters.sort(list);
    notifyListeners();
  }

  Future<void> preloadGitunChannelsFromCache() async {
    if (_gitunChannels.isNotEmpty) return;
    final cached = await SpecialLinkCache.instance.readGitunChannels();
    if (cached == null || cached.isEmpty) return;
    _gitunChannels = PriorityBroadcasters.sort(cached);
    notifyListeners();
  }

  /// Live nav — pinned sports row (Appwrite Sports m3u8 only).
  List<ChannelModel> liveNavTopSportsChannels() => LiveNavTopSports.build(
        mainCatalog: liveTabChannels,
        gitun: _gitunChannels,
      );

  /// All links for the player strip (hub children + M3U alternates + name variants).
  List<StreamLink> playbackLinksFor(ChannelModel channel) =>
      ChannelPlaybackLinks.resolve(channel, _channels);

  bool hasMultiplePlaybackLinks(ChannelModel channel) =>
      ChannelPlaybackLinks.hasMultiple(channel, _channels);

  List<ChannelModel> gitunRelatedChannels({
    required String currentTitle,
    String? currentUrl,
    int limit = 12,
  }) {
    return _gitunChannels
        .where(
          (c) =>
              c.streamUrl.isNotEmpty &&
              c.name != currentTitle &&
              !c.matchesStreamUrl(currentUrl ?? ''),
        )
        .take(limit)
        .toList();
  }

  bool needsStreamHealthCheck(ChannelModel c, {bool force = false}) {
    if (!c.allStreams.any((l) => l.url.isNotEmpty)) return false;
    if (force) return true;
    final checkedAt = _streamHealthAt[c.id];
    if (checkedAt == null || !_streamHealth.containsKey(c.id)) return true;
    return DateTime.now().difference(checkedAt) > _streamHealthTtl;
  }

  ChannelModel? channelById(String id) {
    for (final c in _channels) {
      if (c.id == id) return c;
    }
    return null;
  }

  void clearStreamHealthCache() {
    _streamHealth.clear();
    _streamHealthAt.clear();
    _streamHealthQueue.clear();
    _streamHealthQueuedIds.clear();
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
      if (!needsStreamHealthCheck(c, force: force)) continue;
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
    await drainStreamHealthQueue();
  }

  Future<void> drainStreamHealthQueue() async {
    if (_streamHealthWorkerActive) return;
    _streamHealthWorkerActive = true;

    while (_streamHealthQueue.isNotEmpty) {
      final take = _streamHealthQueue.length > _healthBatchSize
          ? _healthBatchSize
          : _streamHealthQueue.length;
      final batchIds = _streamHealthQueue.sublist(0, take);
      _streamHealthQueue.removeRange(0, take);

      final batch = batchIds
          .map(channelById)
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
        notifyStreamHealthThrottled();
      }

      for (final id in batchIds) {
        _pendingStreamHealthIds.remove(id);
      }
    }

    _streamHealthWorkerActive = false;
    _streamHealthLoading =
        _pendingStreamHealthIds.isNotEmpty || _streamHealthQueue.isNotEmpty;
    notifyStreamHealthThrottled(force: true);
  }

  void notifyStreamHealthThrottled({bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        _lastStreamHealthNotify != null &&
        now.difference(_lastStreamHealthNotify!) <
            const Duration(milliseconds: 750)) {
      return;
    }
    _lastStreamHealthNotify = now;
    notifyListeners();
  }

  /// One background scan after channels load (sports first, capped).
  void scheduleGlobalStreamHealthScan() {
    if (_channels.isEmpty) return;

    final sports = _channels
        .where((c) => c.category == 'Sports' && c.streamUrl.isNotEmpty)
        .take(_sportsHealthScanCap)
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
  bool _channelsLoading = false;
  String? _channelsError;
  bool _catalogFromStaleCache = false;
  bool get channelsLoading => _channelsLoading;
  String? get channelsError => _channelsError;
  bool get catalogFromStaleCache => _catalogFromStaleCache;
  bool get hasChannelsError => _channelsError != null;
  bool get isCatalogSyncing => _channelsLoading;
  String get channelCountLabel => '${_liveChannels.length}';

  bool _homeExtrasScheduled = false;
  Timer? _catalogFollowUpTimer;
  /// Disk cache first (instant UI), then Appwrite refresh in background.
  Future<void> bootstrapCatalog() async {
    final warm = await SpecialLinkCache.instance.readAppCatalogChannels(
      ignoreTtl: true,
    );
    if (warm != null && warm.isNotEmpty) {
      await applyChannelCatalog(warm);
      _scheduleBackgroundCatalogRefresh();
      return;
    }
    await loadChannels();
  }

  void _scheduleBackgroundCatalogRefresh() {
    fetchCatalogInBackground().catchError((Object e, StackTrace st) {
      if (kDebugMode) {
        debugPrint('[ChannelCatalog] background catalog refresh: $e\n$st');
      }
    });
  }

  Future<void> fetchCatalogInBackground() async {
    try {
      final catalog = await CatalogService.instance.loadCatalog(
        forceRefresh: true,
      );
      if (catalog.fromStaleCache) _catalogFromStaleCache = true;
      if (catalog.errorMessage != null) {
        _channelsError ??= catalog.errorMessage;
      }
      if (catalog.channels.isNotEmpty) {
        await applyChannelCatalog(catalog.channels);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ChannelCatalog] background catalog refresh: $e');
      }
    }
  }

  /// Live bottom-nav: Sports + Movies m3u8 from Appwrite catalog only.
  List<ChannelModel> get liveTabChannels =>
      LiveTabChannels.filter(_channels);

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

  // ── News ──────────────────────────────────────────────────

  // ── Channels (GitHub playlist only) ───────────────────────
  Future<void> loadChannels({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final warm = await SpecialLinkCache.instance.readAppCatalogChannels(
        ignoreTtl: true,
      );
      if (warm != null && warm.isNotEmpty && _channels.isEmpty) {
        await applyChannelCatalog(warm);
        _scheduleBackgroundCatalogRefresh();
        return;
      }
    }

    final showLoadingSpinner = _channels.isEmpty;
    if (showLoadingSpinner) {
      _channelsLoading = true;
      _channelsError = null;
      _catalogFromStaleCache = false;
      notifyListeners();
    }

    final catalog = await CatalogService.instance.loadCatalog(
      forceRefresh: forceRefresh,
    );
    _catalogFromStaleCache = catalog.fromStaleCache;
    if (catalog.errorMessage != null) {
      _channelsError = catalog.errorMessage;
    }

    await applyChannelCatalog(catalog.channels);
  }

  Future<void> applyChannelCatalog(List<ChannelModel> raw) async {
    final List<ChannelModel> processed;
    if (raw.length >= 200) {
      processed = await compute(normalizeAndExpandCatalogIsolate, raw);
    } else {
      processed = normalizeAndExpandCatalogIsolate(raw);
    }
    _channels = processed;
    _liveChannels = _channels.where((c) => c.streamUrl.isNotEmpty).toList();
    _byCategoryIndex = null;
    _sportsBrowseCache = null;
    _channelsLoading = false;
    notifyListeners();
    scheduleCatalogFollowUp();
  }

  void ensureCategoryIndex() {
    if (_byCategoryIndex != null) return;
    final map = <String, List<ChannelModel>>{};
    for (final c in _channels) {
      final id = ChannelCategoryRegistry.normalizeId(c.category);
      (map[id] ??= []).add(c);
    }
    _byCategoryIndex = map;
  }

  /// Sports tab pool (Sports + BD cricket broadcasters), sorted once per catalog load.
  List<ChannelModel> get sportsBrowseChannels {
    _sportsBrowseCache ??= SportsChannelPriority.sortLiveSports(
      SportChannelIcons.browseChannels(_channels),
    );
    return _sportsBrowseCache!;
  }

  void scheduleCatalogFollowUp() {
    _homeExtrasScheduled = true;
    _catalogFollowUpTimer?.cancel();
    _catalogFollowUpTimer = Timer(const Duration(milliseconds: 900), () {
      if (_channels.isEmpty) return;
      final follow = onCatalogFollowUp;
      if (follow != null) {
        unawaited(follow());
      }
      unawaited(preloadGitunChannelsFromCache());
    });
  }

  /// Live tab: GITUN + stream probes (not on cold start).
  void onLiveTabSelected() {
    unawaited(ensureGitunChannelsLoaded());
    if (_streamHealthScanScheduled || _channels.isEmpty) return;
    _streamHealthScanScheduled = true;
    scheduleGlobalStreamHealthScan();
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
    ensureCategoryIndex();
    final normalized = ChannelCategoryRegistry.normalizeId(cat);
    return List<ChannelModel>.from(
      _byCategoryIndex![normalized] ?? const [],
    );
  }

  /// Categories tab rows — only genres that have channels (+ Special Link).
  List<List<Object>> get categoriesGenreRows =>
      ChannelCategoryRegistry.genreRowsForChannels(_channels);

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
    final normalized = normalizeCategory(category);
    var list = _channels.where((c) => c.streamUrl.isNotEmpty);
    if (normalized != null) {
      list = list.where((c) => c.category == normalized);
    }
    final sorted = list.toList()..sort(PriorityBroadcasters.compare);
    return sorted
        .where((c) => !c.matchesStreamUrl(excludeStreamUrl ?? ''))
        .take(12)
        .toList();
  }

  static String? normalizeCategory(String? category) {
    if (category == null || category.isEmpty) return null;
    if (category == 'Bangla') return 'Bangladesh';
    return category;
  }

  String categoryForRelated(ChannelModel channel, {String? browseCategory}) {
    if (browseCategory != null && browseCategory.isNotEmpty) {
      if (isGitunBrowseCategory(browseCategory)) return 'GITUN';
      return normalizeCategory(browseCategory) ?? browseCategory;
    }
    if (channel.category == 'GITUN') return 'GITUN';
    final inferred = ChannelCategoryRegistry.fromGroupTitle(
      channel.currentShow,
      channel.name,
    );
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
      case 'GITUN':
        return 'MORE GITUN CHANNELS';
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

  List<ChannelModel> pickSportsChannelsForMatch(List<String> keywords,
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

  void clearStreamHealthOnRefresh() {
    clearStreamHealthCache();
    _streamHealthScanScheduled = false;
    _homeExtrasScheduled = false;
    _catalogFollowUpTimer?.cancel();
  }
}
