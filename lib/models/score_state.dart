import 'model.dart';

/// Sealed class for score loading states — no fake data, honest states only.
sealed class ScoreState {
  const ScoreState();
}

/// Initial state before any fetch attempt
class ScoreInitial extends ScoreState {
  const ScoreInitial();
}

/// Loading state — show skeleton while fetching
class ScoreLoading extends ScoreState {
  const ScoreLoading();
}

/// Successfully loaded live scores
class ScoreLoaded extends ScoreState {
  final List<MatchModel> liveMatches;
  final List<MatchModel> todayMatches;
  final List<MatchModel> upcomingMatches;
  final List<MatchModel> predictions;
  final DateTime loadedAt;

  const ScoreLoaded({
    required this.liveMatches,
    required this.todayMatches,
    required this.upcomingMatches,
    required this.predictions,
    required this.loadedAt,
  });
}

/// Cached data from previous successful fetch (offline)
class ScoreCached extends ScoreState {
  final List<MatchModel> liveMatches;
  final List<MatchModel> todayMatches;
  final List<MatchModel> upcomingMatches;
  final List<MatchModel> predictions;
  final DateTime cachedAt;
  final Duration cacheAge;

  const ScoreCached({
    required this.liveMatches,
    required this.todayMatches,
    required this.upcomingMatches,
    required this.predictions,
    required this.cachedAt,
    required this.cacheAge,
  });
}

/// Network error — no connection
class ScoreNetworkError extends ScoreState {
  final String message;
  final DateTime failedAt;

  const ScoreNetworkError({
    required this.message,
    required this.failedAt,
  });
}

/// API error — 4xx/5xx from server
class ScoreApiError extends ScoreState {
  final String message;
  final int? statusCode;
  final DateTime failedAt;

  const ScoreApiError({
    required this.message,
    this.statusCode,
    required this.failedAt,
  });
}

/// Parse error — invalid response format
class ScoreParseError extends ScoreState {
  final String message;
  final DateTime failedAt;

  const ScoreParseError({
    required this.message,
    required this.failedAt,
  });
}

/// Empty state — no live matches right now
class ScoreEmpty extends ScoreState {
  final DateTime checkedAt;

  const ScoreEmpty({required this.checkedAt});
}

/// Timeout error — request took too long
class ScoreTimeoutError extends ScoreState {
  final Duration timeout;
  final DateTime failedAt;

  const ScoreTimeoutError({
    required this.timeout,
    required this.failedAt,
  });
}

/// Unknown error
class ScoreUnknownError extends ScoreState {
  final String message;
  final DateTime failedAt;

  const ScoreUnknownError({
    required this.message,
    required this.failedAt,
  });
}
