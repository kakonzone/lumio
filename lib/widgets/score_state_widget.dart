import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lumio_tv/models/score_state.dart';
import 'package:lumio_tv/provider/live_score_provider.dart';
import 'package:provider/provider.dart';

/// Widget that displays honest score states - no fake data.
/// Handles loading, error, empty, cached states with appropriate UI.
class ScoreStateWidget extends StatelessWidget {
  const ScoreStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final scoreState = context.watch<LiveScoreProvider>().scoreState;

    return switch (scoreState) {
      ScoreInitial() => const _InitialState(),
      ScoreLoading() => const _LoadingState(),
      ScoreLoaded() => const SizedBox.shrink(),
      ScoreCached() => _CachedState(state: scoreState as ScoreCached),
      ScoreNetworkError() => _NetworkErrorState(state: scoreState as ScoreNetworkError),
      ScoreApiError() => _ApiErrorState(state: scoreState as ScoreApiError),
      ScoreParseError() => _ParseErrorState(state: scoreState as ScoreParseError),
      ScoreTimeoutError() => _TimeoutErrorState(state: scoreState as ScoreTimeoutError),
      ScoreUnknownError() => _UnknownErrorState(state: scoreState as ScoreUnknownError),
      ScoreEmpty() => const _EmptyState(),
    };
  }
}

class _InitialState extends StatelessWidget {
  const _InitialState();

  @override
  Widget build(BuildContext context) {
    // Initial state - show loading skeleton
    return const _LoadingState();
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SkeletonScoreCard(),
        _SkeletonScoreCard(),
        _SkeletonScoreCard(),
      ],
    );
  }

  Widget _SkeletonScoreCard() {
    return Container(
      height: 140,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

class _CachedState extends StatelessWidget {
  final ScoreCached state;
  const _CachedState({required this.state});

  @override
  Widget build(BuildContext context) {
    // Show cached data with offline badge
    return Column(
      children: [
        if (kDebugMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade400),
            ),
            child: Text(
              '⚠️ DEBUG: Cached data (${_formatCacheAge(state.cacheAge)})',
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade800.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade600),
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_off, color: Colors.grey, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Last updated ${_formatCacheAge(state.cacheAge)} ago • offline',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatCacheAge(Duration age) {
    if (age.inMinutes < 1) return '${age.inSeconds}s';
    if (age.inHours < 1) return '${age.inMinutes}m';
    if (age.inDays < 1) return '${age.inHours}h';
    return '${age.inDays}d';
  }
}

class _NetworkErrorState extends StatelessWidget {
  final ScoreNetworkError state;
  const _NetworkErrorState({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.wifi_off, color: Colors.grey.shade500, size: 48),
        const SizedBox(height: 16),
        const Text(
          'No internet connection',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Check your connection and tap to retry',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => context.read<LiveScoreProvider>().retryLoadMatches(),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _ApiErrorState extends StatelessWidget {
  final ScoreApiError state;
  const _ApiErrorState({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.cloud_off, color: Colors.grey.shade500, size: 48),
        const SizedBox(height: 16),
        Text(
          state.statusCode != null 
              ? 'Server error (${state.statusCode})'
              : 'API unavailable',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Score service is temporarily unavailable',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => context.read<LiveScoreProvider>().retryLoadMatches(),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _ParseErrorState extends StatelessWidget {
  final ScoreParseError state;
  const _ParseErrorState({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.error_outline, color: Colors.orange.shade500, size: 48),
        const SizedBox(height: 16),
        const Text(
          'Invalid response format',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Score service returned unexpected data',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => context.read<LiveScoreProvider>().retryLoadMatches(),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade600,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _TimeoutErrorState extends StatelessWidget {
  final ScoreTimeoutError state;
  const _TimeoutErrorState({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.access_time, color: Colors.grey, size: 48),
        const SizedBox(height: 16),
        const Text(
          'Request timed out',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Server took too long to respond',
          style: TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => context.read<LiveScoreProvider>().retryLoadMatches(),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade600,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _UnknownErrorState extends StatelessWidget {
  final ScoreUnknownError state;
  const _UnknownErrorState({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.error, color: Colors.red.shade500, size: 48),
        const SizedBox(height: 16),
        const Text(
          'Something went wrong',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Unable to load scores',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => context.read<LiveScoreProvider>().retryLoadMatches(),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.sports_cricket, color: Colors.grey.shade600, size: 48),
        const SizedBox(height: 16),
        const Text(
          'No live matches right now',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Check back later for live cricket and football scores',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
