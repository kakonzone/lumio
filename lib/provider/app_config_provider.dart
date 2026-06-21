import 'package:flutter/foundation.dart';

import '../models/app_config_model.dart';
import '../services/app_config_service.dart';

/// Remote app configuration — Appwrite `global_config`.
class AppConfigProvider extends ChangeNotifier {
  AppConfigModel _config = AppConfigModel.defaultConfig();
  bool _isLoading = false;
  bool _initialized = false;

  AppConfigModel get config => _config;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await refresh();
  }

  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      _config = await AppConfigService.instance.fetchConfig(
        forceRefresh: true,
      );
    } catch (e) {
      debugPrint('[AppConfig] fetch failed (using defaults): $e');
      // Keep default config — do not rethrow
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
