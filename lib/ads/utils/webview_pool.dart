import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../../services/firebase_bootstrap.dart';

/// Limits concurrent native WebView mounts to reduce memory churn (Week 2).
class WebViewPool extends ChangeNotifier {
  WebViewPool._();
  static final WebViewPool instance = WebViewPool._();

  static const int _defaultMaxConcurrent = 3;
  static const String _rcKeyMaxConcurrent = 'webview_pool_max_concurrent';

  int _maxConcurrent = _defaultMaxConcurrent;
  bool _rcLoaded = false;

  int get maxConcurrent => _maxConcurrent;

  Future<void> ensureRemoteConfigLoaded() async {
    if (_rcLoaded) return;
    _rcLoaded = true;
    try {
      if (!FirebaseBootstrap.isInitialized) return;
      final value =
          FirebaseRemoteConfig.instance.getInt(_rcKeyMaxConcurrent);
      if (value >= 1 && value <= 8) {
        _maxConcurrent = value;
        if (kDebugMode) {
          debugPrint('[WebViewPool] RC maxConcurrent=$_maxConcurrent');
        }
      }
    } catch (_) {
      _maxConcurrent = _defaultMaxConcurrent;
    }
  }

  /// Under memory pressure, halve active slots until next RC refresh.
  void applyMemoryPressure() {
    final reduced = (_maxConcurrent / 2).floor().clamp(1, _maxConcurrent);
    if (reduced < _maxConcurrent) {
      _maxConcurrent = reduced;
      if (kDebugMode) {
        debugPrint('[WebViewPool] memory pressure → max=$_maxConcurrent');
      }
    }
  }

  final Set<String> _active = {};
  final Map<String, DateTime> _lastDeferLogAt = {};

  bool canAcquire(String placement) =>
      _active.contains(placement) || _active.length < _maxConcurrent;

  /// Returns false when pool is full — caller should show placeholder.
  bool acquire(String placement) {
    if (_active.contains(placement)) return true;
    if (_active.length >= _maxConcurrent) {
      final now = DateTime.now();
      final last = _lastDeferLogAt[placement];
      final shouldLog = last == null || now.difference(last) >= const Duration(seconds: 8);
      if (kDebugMode && shouldLog) {
        debugPrint('[WebViewPool] defer $placement (active=${_active.length})');
        _lastDeferLogAt[placement] = now;
      }
      return false;
    }
    _active.add(placement);
    notifyListeners();
    return true;
  }

  void release(String placement) {
    if (_active.remove(placement)) {
      notifyListeners();
    }
  }

  bool holdsPlacement(String placement) => _active.contains(placement);

  /// [IndexedStack] keeps every tab alive — free other tabs' list slots on nav change.
  void releasePlacementsForTab(int navIndex) {
    final keepPrefixes = switch (navIndex) {
      0 => const ['home_'],
      1 => const ['sports_list', 'floating_'],
      2 => const ['live_list'],
      3 => const <String>[],
      4 => const ['category_list'],
      _ => const <String>[],
    };
    releaseExceptPrefixes(keepPrefixes);
  }

  void releaseExceptPrefixes(List<String> keepPrefixes) {
    if (_active.isEmpty) return;
    final toRemove = _active
        .where(
          (p) => keepPrefixes.isEmpty ||
              !keepPrefixes.any((prefix) => p.startsWith(prefix)),
        )
        .toList();
    if (toRemove.isEmpty) return;
    for (final p in toRemove) {
      _active.remove(p);
    }
    if (kDebugMode) {
      debugPrint(
        '[WebViewPool] tab release removed=${toRemove.length} '
        'keep=$keepPrefixes remaining=${_active.length}',
      );
    }
    notifyListeners();
  }

  /// Frees pool slots when the app backgrounds so list ads can remount cleanly.
  void releaseAllOnBackground() {
    if (_active.isEmpty) return;
    if (kDebugMode) {
      debugPrint('[WebViewPool] background release (${_active.length} active)');
    }
    _active.clear();
    _lastDeferLogAt.clear();
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _active.clear();
    _lastDeferLogAt.clear();
  }
}
