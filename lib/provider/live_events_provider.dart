import 'package:flutter/foundation.dart';

import '../models/model.dart';
import '../models/live_event_match.dart';
import '../services/live_events_service.dart';
import '../services/featured_live_events_service.dart';
import '../services/featured_live_events_cache.dart';
import '../utils/live_event_sort.dart';
import '../../utils/app_logger.dart';

/// Live events provider.
/// 
/// Handles football/cricket live events and featured live events.
/// Extracted from AppProvider for granular updates.
class LiveEventsProvider extends ChangeNotifier {
  static const _loggerName = 'LiveEventsProvider';
  
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
  FeaturedLiveEventsSource _featuredLiveEventsSource = FeaturedLiveEventsSource.empty;
  String? _featuredLiveEventsRemoteUpdatedAt;
  String? _featuredLiveEventsError;

  // Football live events
  List<LiveEventMatch> get liveEventFootball => _liveEventFootball;
  
  // Cricket live events
  List<LiveEventMatch> get liveEventCricket => _liveEventCricket;
  
  // All live events
  List<LiveEventMatch> get liveEventAll => _liveEventAll;
  bool get liveEventsLoading => _liveEventsLoading;
  bool get hasLiveEventsData =>
      _liveEventAll.isNotEmpty ||
      _liveEventFootball.isNotEmpty ||
      _liveEventCricket.isNotEmpty;

  // Featured events
  List<LiveEventMatch> get featuredLiveEvents => _featuredLiveEvents;
  String get featuredLiveEventsSectionTitle => _featuredSectionTitle;
  String get featuredLiveEventsSectionSubtitle => _featuredSectionSubtitle;
  bool get featuredLiveEventsLoading => _featuredLiveEventsLoading;
  bool get hasFeaturedLiveEventsData => _featuredLiveEvents.isNotEmpty;
  FeaturedLiveEventsSource get featuredLiveEventsSource => _featuredLiveEventsSource;
  String? get featuredLiveEventsRemoteUpdatedAt => _featuredLiveEventsRemoteUpdatedAt;
  String? get featuredLiveEventsError => _featuredLiveEventsError;
  bool get featuredLiveEventsFromRemote =>
      _featuredLiveEventsSource == FeaturedLiveEventsSource.appwrite ||
      _featuredLiveEventsSource == FeaturedLiveEventsSource.github;

  @Deprecated('Use featuredLiveEventsFromRemote')
  bool get featuredLiveEventsFromAppwrite => featuredLiveEventsFromRemote;

  /// Status line shown when featured events failed to load.
  String get featuredLiveEventsStatusLine {
    if (_featuredLiveEventsError != null &&
        _featuredLiveEventsError!.trim().isNotEmpty) {
      return _featuredLiveEventsError!;
    }
    return '';
  }

  /// Sorted live events (all or by sport).
  List<LiveEventMatch> get sortedLiveEvents {
    if (_liveEventAll.isNotEmpty) return _liveEventAll;
    return LiveEventSort.sort([
      ..._liveEventFootball,
      ..._liveEventCricket,
    ]);
  }

  LiveEventsProvider();

  /// Load live events with caching.
  Future<void> loadLiveEvents({
    required List<ChannelModel> channels, 
    bool force = false
  }) async {
    if (channels.isEmpty) return;

    final cacheFresh = _liveEventsLoadedAt != null &&
        DateTime.now().difference(_liveEventsLoadedAt!) < _liveEventsTtl;
    if (!force && hasLiveEventsData && cacheFresh) {
      AppLogger.fine('Cache hit - skip fetch', subsystem: _loggerName);
      return;
    }

    if (!hasLiveEventsData) {
      _liveEventsLoading = true;
      notifyListeners();
    }

    AppLogger.info('Loading live events...', subsystem: _loggerName);

    try {
      final bundle = await LiveEventsService.fetch(channels);
      _liveEventAll = bundle.all;
      _liveEventFootball = bundle.football;
      _liveEventCricket = bundle.cricket;
      _liveEventsLoadedAt = DateTime.now();
      AppLogger.info(
          'Loaded ${_liveEventFootball.length} football, '
          '${_liveEventCricket.length} cricket events',
          subsystem: _loggerName,
      );
    } catch (e, st) {
      if (!hasLiveEventsData) {
        _liveEventFootball = [];
        _liveEventCricket = [];
        _liveEventAll = [];
      }
      AppLogger.severe('Failed to load live events', subsystem: _loggerName, error: e, stackTrace: st);
    } finally {
      _liveEventsLoading = false;
      notifyListeners();
    }
  }

  /// Load featured live events with caching.
  Future<void> loadFeaturedLiveEvents({bool force = false}) async {
    if (!hasFeaturedLiveEventsData) {
      _featuredLiveEventsLoading = true;
      notifyListeners();
    }

    AppLogger.info('Loading featured live events...', subsystem: _loggerName);

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
      AppLogger.info(
          'Loaded ${_featuredLiveEvents.length} featured events from ${result.source}',
          subsystem: _loggerName,
      );
    } catch (e, st) {
      if (!hasFeaturedLiveEventsData) {
        _featuredLiveEvents = [];
        _featuredLiveEventsSource = FeaturedLiveEventsSource.empty;
      }
      _featuredLiveEventsError = e.toString();
      AppLogger.severe('Failed to load featured events', subsystem: _loggerName, error: e, stackTrace: st);
    } finally {
      _featuredLiveEventsLoading = false;
      notifyListeners();
    }
  }

  /// Clear all live events data.
  void clearCache() {
    _liveEventFootball = [];
    _liveEventCricket = [];
    _liveEventAll = [];
    _liveEventsLoadedAt = null;
    _featuredLiveEvents = [];
    _featuredLiveEventsSource = FeaturedLiveEventsSource.empty;
    _featuredLiveEventsError = null;
    notifyListeners();
    AppLogger.info('Cleared cache', subsystem: _loggerName);
  }

  /// Refresh all live events.
  Future<void> refresh({required List<ChannelModel> channels}) async {
    await FeaturedLiveEventsCache.instance.clear();
    _liveEventsLoadedAt = null;
    await Future.wait([
      loadFeaturedLiveEvents(force: true),
      loadLiveEvents(channels: channels, force: true),
    ]);
  }
}
