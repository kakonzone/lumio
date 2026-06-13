import 'dart:async';
import 'dart:math';

import 'package:lumio_tv/l10n/strings.dart';

/// Loading message types
enum LoadingContext {
  data,
  search,
  playback,
  network,
  onboarding,
  sync,
  generic,
}

/// Contextual loading messages
///
/// Replaces generic "Loading..." with personality-rich, contextual messages
/// Messages cycle every 2 seconds during operations > 1 second
class LoadingMessages {
  static final Random _random = Random();
  static Timer? _cycleTimer;
  static String _currentMessage = '';
  static int _currentIndex = 0;
  static List<String> _messages = [];
  static bool _isCycling = false;

  /// Get contextual loading messages for a context
  static List<String> getMessages(LoadingContext context) {
    switch (context) {
      case LoadingContext.data:
        return [
          Strings.loadingTuningIn,
          Strings.loadingFindingChannels,
          Strings.loadingWarmingUp,
          Strings.loadingLoadingLibrary,
        ];
      case LoadingContext.search:
        return [
          Strings.loadingSearching,
          Strings.loadingRefiningResults,
          Strings.loadingLookingUp,
        ];
      case LoadingContext.playback:
        return [
          Strings.loadingWarmingUpPlayback,
          Strings.loadingBuffering,
          Strings.loadingConnecting,
          Strings.loadingPreparingStream,
        ];
      case LoadingContext.network:
        return [
          Strings.loadingConnectingNetwork,
          Strings.loadingSyncing,
          Strings.loadingCheckingConnection,
        ];
      case LoadingContext.onboarding:
        return [
          Strings.loadingGettingReady,
          Strings.loadingAlmostThere,
          Strings.loadingSettingUp,
        ];
      case LoadingContext.sync:
        return [
          Strings.loadingSyncing,
          Strings.loadingSyncing,
          Strings.loadingCheckingConnection,
        ];
      case LoadingContext.generic:
        return [
          Strings.loadingLoading,
          Strings.loadingOneMoment,
          Strings.loadingGettingReadyGeneric,
        ];
    }
  }

  /// Get a random message from a context
  static String getRandom(LoadingContext context) {
    final messages = getMessages(context);
    return messages[_random.nextInt(messages.length)];
  }

  /// Get a message at index (for cycling)
  static String getAtIndex(LoadingContext context, int index) {
    final messages = getMessages(context);
    return messages[index % messages.length];
  }

  /// Start cycling messages every 2 seconds
  ///
  /// Call this for operations > 1 second
  /// Returns the initial message
  static String startCycling(LoadingContext context) {
    if (_isCycling) {
      stopCycling();
    }

    _messages = getMessages(context);
    _currentIndex = 0;
    _currentMessage = _messages[_currentIndex];
    _isCycling = true;

    _cycleTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _currentIndex = (_currentIndex + 1) % _messages.length;
      _currentMessage = _messages[_currentIndex];
    });

    return _currentMessage;
  }

  /// Get the current cycling message
  static String getCurrentMessage() {
    if (!_isCycling) {
      return "Loading...";
    }
    return _currentMessage;
  }

  /// Stop cycling messages
  static void stopCycling() {
    _cycleTimer?.cancel();
    _cycleTimer = null;
    _isCycling = false;
    _currentIndex = 0;
    _messages = [];
    _currentMessage = '';
  }

  /// Check if cycling is active
  static bool get isCycling => _isCycling;

  /// Convenience method for data loading
  static String data() => getRandom(LoadingContext.data);

  /// Convenience method for search
  static String search() => getRandom(LoadingContext.search);

  /// Convenience method for playback
  static String playback() => getRandom(LoadingContext.playback);

  /// Convenience method for network
  static String network() => getRandom(LoadingContext.network);

  /// Convenience method for onboarding
  static String onboarding() => getRandom(LoadingContext.onboarding);

  /// Convenience method for sync
  static String sync() => getRandom(LoadingContext.sync);

  /// Convenience method for generic
  static String generic() => getRandom(LoadingContext.generic);
}
