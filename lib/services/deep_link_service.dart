import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'attribution_service.dart';

/// Android VIEW intents → attribution + optional channel/tab routing.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const MethodChannel _channel =
      MethodChannel('com.kakonzone.lumio/deeplink');

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await captureInitialLink();
  }

  Future<void> captureInitialLink() async {
    try {
      final link = await _channel.invokeMethod<String>('getInitialLink');
      if (link == null || link.trim().isEmpty) return;
      await _handleLink(link);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeepLink] getInitialLink failed: $e');
      }
    }
  }

  /// Warm-start links (app already running).
  Future<void> capturePendingLink() async {
    try {
      final link = await _channel.invokeMethod<String>('pollPendingLink');
      if (link == null || link.trim().isEmpty) return;
      await _handleLink(link);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeepLink] pollPendingLink failed: $e');
      }
    }
  }

  Future<void> _handleLink(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    if (!_isSupported(uri)) return;
    await AttributionService.instance.handleUri(uri);
  }

  bool _isSupported(Uri uri) {
    if (uri.scheme == 'lumio') return true;
    if (uri.scheme == 'https' &&
        (uri.host == 'lumio.app' || uri.host == 'www.lumio.app')) {
      return uri.path.startsWith('/open') || uri.path.startsWith('/channel');
    }
    return false;
  }
}
