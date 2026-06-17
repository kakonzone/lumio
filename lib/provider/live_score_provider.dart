import 'package:flutter/foundation.dart';

import '../models/model.dart';
import '../models/score_state.dart';
import '../services/footystream_service.dart';
import '../services/score_service.dart';
import '../utils/schedule_merge.dart';
import '../../utils/app_logger.dart';

/// Live match scores and sports data provider.
/// 
/// Handles ESPN/Cricbuzz scores, tournaments, and match state.
/// Extracted from AppProvider for granular updates.
class LiveScoreProvider extends ChangeNotifier {
  static const _loggerName = 'LiveScoreProvider';
  
  List<MatchModel> _liveMatches = [];
  List<MatchModel> _todayMatches = [];
  List<MatchModel> _upcomingMatches = [];
  List<MatchModel> _predictions = [];
  List<ScoreTournamentGroup> _scoreGroups = [];
  
  bool _matchesLoading = false;
  bool _scoresRequested = false;
  String? _matchesError;
  ScoreState _scoreState = const ScoreInitial();

  // Getters
  List<MatchModel> get liveMatches => _liveMatches;
  List<MatchModel> get todayMatches => _todayMatches;
  List<MatchModel> get upcomingMatches => _upcomingMatches;
  List<MatchModel> get predictions => _predictions;
  List<ScoreTournamentGroup> get scoreGroups => _scoreGroups;
  bool get matchesLoading => _matchesLoading;
  bool get scoresRequested => _scoresRequested;
  String? get matchesError => _matchesError;
  bool get hasMatchesError => _matchesError != null;
  ScoreState get scoreState => _scoreState;

  // Computed getters
  List<MatchModel> get scoreCardMatches =>
      _scoreGroups.expand((g) => g.matches).toList();

  List<MatchModel> get internationalScoreMatches =>
      _scoreGroups.expand((g) => g.matches)
          .where((m) => _isInternational(m))
          .toList();

  List<MatchModel> get premierLeagueScoreMatches =>
      _scoreGroups.expand((g) => g.matches)
          .where((m) => _isPremierLeague(m))
          .toList();

  LiveScoreProvider();

  /// Lazy-load scores (avoids blocking startup).
  Future<void> ensureScoresLoaded() async {
    if (_matchesLoading) return;
    if (_scoresRequested && _scoreGroups.isNotEmpty) return;
    _scoresRequested = true;
    await loadMatches();
  }

  /// Retry loading matches after error.
  Future<void> retryLoadMatches() async {
    if (_matchesLoading) return;
    ScoreService.clearCache();
    await loadMatches();
  }

  /// Load match data from multiple sources.
  Future<void> loadMatches() async {
    _matchesLoading = true;
    _matchesError = null;
    _scoreState = const ScoreLoading();
    notifyListeners();
    
    AppLogger.info('Loading matches...', subsystem: _loggerName);

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
        _todayMatches = mergedToday;
        _liveMatches = mergedToday.where((m) => m.isLive).toList();
        _upcomingMatches = mergedToday.where((m) => m.isUpcoming).toList();
      } else {
        _todayMatches = [];
        _liveMatches = [];
        _upcomingMatches = [];
      }

      _scoreState = ScoreLoaded(
        liveMatches: _liveMatches,
        todayMatches: _todayMatches,
        upcomingMatches: _upcomingMatches,
        predictions: _predictions,
        loadedAt: DateTime.now(),
      );
      AppLogger.info(
          'Loaded ${_scoreGroups.length} tournaments, '
          '${_todayMatches.length} matches',
          subsystem: _loggerName,
      );
    } catch (e, st) {
      _matchesError = e.toString();
      _scoreState = ScoreUnknownError(
        message: 'Failed to load scores',
        failedAt: DateTime.now(),
      );
      AppLogger.severe('Failed to load matches', subsystem: _loggerName, error: e, stackTrace: st);
      
      // Set empty states on error
      _todayMatches = [];
      _liveMatches = [];
      _upcomingMatches = [];
      _predictions = [];
    } finally {
      _matchesLoading = false;
      notifyListeners();
    }
  }

  /// Clear all cached data.
  void clearCache() {
    ScoreService.clearCache();
    FootyStreamService.clearCache();
    _liveMatches = [];
    _todayMatches = [];
    _upcomingMatches = [];
    _predictions = [];
    _scoreGroups = [];
    _matchesError = null;
    _scoreState = const ScoreInitial();
    _scoresRequested = false;
    notifyListeners();
    AppLogger.info('Cleared cache', subsystem: _loggerName);
  }

  // Helper methods for computed properties
  bool _isInternational(MatchModel match) {
    final sport = match.sport.toLowerCase();
    return sport.contains('international') || 
           sport.contains('world cup') ||
           sport.contains('euro');
  }

  bool _isPremierLeague(MatchModel match) {
    final sport = match.sport.toLowerCase();
    return sport.contains('premier') || 
           sport.contains('epl') ||
           match.teamA.toLowerCase().contains('premier') ||
           match.teamB.toLowerCase().contains('premier');
  }
}
