import 'dart:async';

import 'package:flutter/foundation.dart';

/// Tracks scroll inactivity for floating native cards (30s default).
class ScrollIdleNotifier extends ChangeNotifier {
  ScrollIdleNotifier({
    this.idleThreshold = const Duration(seconds: 30),
  });

  final Duration idleThreshold;

  Timer? _idleTimer;
  bool _idleReached = false;
  bool _suppressed = false;

  bool get idleReached => _idleReached && !_suppressed;

  void attach() {
    _resetIdleTimer();
  }

  void onUserScroll() {
    if (_idleReached) {
      _idleReached = false;
      notifyListeners();
    }
    _resetIdleTimer();
  }

  void suppress() {
    _suppressed = true;
    _idleReached = false;
    _idleTimer?.cancel();
    notifyListeners();
  }

  void resume() {
    if (!_suppressed) return;
    _suppressed = false;
    _resetIdleTimer();
    notifyListeners();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleThreshold, () {
      if (_suppressed) return;
      _idleReached = true;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }
}
