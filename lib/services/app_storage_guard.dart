import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../core/performance_tuning.dart';
import '../utils/lumio_image_cache.dart';

/// Keeps app **data** small so fat APK (~45–55 MB) + cache stays ≤~80 MB in Settings.
///
/// (Install "App" size ≈ APK native libs; "Data" is capped here — WebView ads grew to 800MB+ without this.)
class AppStorageGuard {
  AppStorageGuard._();

  static const MethodChannel _channel =
      MethodChannel('com.kakonzone.lumio/storage');

  /// Max Flutter-accessible app data (cache + internal files) after trim.
  static const int maxAppDataBudgetBytes = 22 * 1024 * 1024;

  /// Start trimming before hard cap (fat APK leaves ~25 MB headroom for data).
  static int get softBudgetBytes =>
      PerformanceTuning.isLowRam ? 6 * 1024 * 1024 : 10 * 1024 * 1024;

  static const int hardBudgetBytes = maxAppDataBudgetBytes;

  static Timer? _periodic;
  static bool _trimInFlight = false;

  static void schedule() {
    _periodic?.cancel();
    unawaited(trimIfNeeded(reason: 'startup'));
    _periodic = Timer.periodic(
      const Duration(hours: 6),
      (_) => unawaited(trimIfNeeded(reason: 'periodic')),
    );
  }

  static void onAppResumed() {
    unawaited(trimIfNeeded(reason: 'resume'));
  }

  static Future<void> trimIfNeeded({required String reason}) async {
    if (!Platform.isAndroid || _trimInFlight) return;
    _trimInFlight = true;
    try {
      final cacheBytes = await _getCacheBytes();
      final appDataBytes = await _getAppDataBytes();
      if (kDebugMode) {
        debugPrint(
          '[AppStorage] check reason=$reason '
          'cache=${cacheBytes ~/ (1024 * 1024)}MB '
          'data=${appDataBytes ~/ (1024 * 1024)}MB',
        );
      }
      if (cacheBytes < softBudgetBytes && appDataBytes < softBudgetBytes) {
        return;
      }

      await _runTrimPass(maxCacheBytes: 8 * 1024 * 1024);

      var afterCache = await _getCacheBytes();
      var afterData = await _getAppDataBytes();
      if (afterCache > hardBudgetBytes || afterData > hardBudgetBytes) {
        await _runTrimPass(maxCacheBytes: 4 * 1024 * 1024);
        afterCache = await _getCacheBytes();
        afterData = await _getAppDataBytes();
      }
      if (kDebugMode) {
        debugPrint(
          '[AppStorage] trimmed reason=$reason '
          'cache ${cacheBytes ~/ (1024 * 1024)}→${afterCache ~/ (1024 * 1024)}MB '
          'data ${appDataBytes ~/ (1024 * 1024)}→${afterData ~/ (1024 * 1024)}MB',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppStorage] trim failed: $e');
      }
    } finally {
      _trimInFlight = false;
    }
  }

  static Future<void> _runTrimPass({required int maxCacheBytes}) async {
    await _clearWebViewCache();
    // Keep in-memory Adsterra HTML cache — clearing while WebViews are mounted
    // causes nap5k/monetag IDB races and "destroyed WebView" warnings on MIUI.
    await lumioImageCache.emptyCache();
    await DefaultCacheManager().emptyCache();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await _channel.invokeMethod<void>(
      'trimCacheDir',
      {'maxBytes': maxCacheBytes},
    );
    await _channel.invokeMethod<void>(
      'trimAppDataDir',
      {'maxBytes': maxAppDataBudgetBytes},
    );
  }

  static Future<int> _getCacheBytes() async {
    try {
      final value = await _channel.invokeMethod<int>('getCacheBytes');
      return value ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> _getAppDataBytes() async {
    try {
      final value = await _channel.invokeMethod<int>('getAppDataBytes');
      return value ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _clearWebViewCache() async {
    try {
      await _channel.invokeMethod<void>('clearWebViewCache');
    } catch (_) {}
  }
}
