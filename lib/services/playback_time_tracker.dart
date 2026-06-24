import 'dart:async';

import 'package:flutter/foundation.dart';

/// Tracks playback time and triggers rewarded ads at specific intervals.
/// Triggers: 0s (start), 20min, 50min, then every 40min (90min, 130min, etc.)
class PlaybackTimeTracker {
  Timer? _timer;
  Duration _totalPlaybackTime = Duration.zero;
  DateTime? _lastUpdateTime;
  bool _isPlaying = false;
  final Set<int> _triggeredMinutes = {};

  // Trigger points in minutes
  static const List<int> _triggerMinutes = [0, 20, 50];
  static const int _repeatIntervalMinutes = 40;

  /// Callback when a trigger point is reached.
  /// Returns the number of ads to show (1 or 2).
  final Future<int> Function(int minute) onTriggerReached;

  PlaybackTimeTracker({required this.onTriggerReached});

  void start() {
    if (_isPlaying) return;
    _isPlaying = true;
    _lastUpdateTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void pause() {
    _isPlaying = false;
    _timer?.cancel();
    _lastUpdateTime = null;
  }

  void reset() {
    pause();
    _totalPlaybackTime = Duration.zero;
    _triggeredMinutes.clear();
  }

  void _tick() {
    if (!_isPlaying || _lastUpdateTime == null) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastUpdateTime!);
    _lastUpdateTime = now;
    _totalPlaybackTime += elapsed;

    final totalMinutes = _totalPlaybackTime.inMinutes;
    
    if (_triggeredMinutes.contains(totalMinutes)) return;

    // Check if this minute is a trigger point
    if (_shouldTriggerAt(totalMinutes)) {
      _triggeredMinutes.add(totalMinutes);
      final adsToShow = _getAdsCountForMinute(totalMinutes);
      
      if (kDebugMode) {
        debugPrint('[PlaybackTimeTracker] Trigger at ${totalMinutes}min, showing $adsToShow ads');
      }
      
      onTriggerReached(totalMinutes).then((adsShown) {
        if (kDebugMode) {
          debugPrint('[PlaybackTimeTracker] Shown $adsShown ads at ${totalMinutes}min');
        }
      });
    }
  }

  bool _shouldTriggerAt(int minutes) {
    // Initial triggers
    if (_triggerMinutes.contains(minutes)) return true;
    
    // Repeating triggers after 50min (90min, 130min, 170min, etc.)
    if (minutes > 50 && (minutes - 50) % _repeatIntervalMinutes == 0) {
      return true;
    }
    
    return false;
  }

  int _getAdsCountForMinute(int minutes) {
    // 50min trigger shows 2 ads
    if (minutes == 50) return 2;
    
    // All other triggers show 1 ad
    return 1;
  }

  Duration get totalPlaybackTime => _totalPlaybackTime;
  bool get isPlaying => _isPlaying;
}
