import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_logger.dart';

/// Theme management provider.
/// 
/// Handles dark/light theme preference and persistence.
/// Separate from favorites to allow granular UI updates.
class ThemeProvider extends ChangeNotifier {
  static const _themeKey = 'lumio_theme_dark';
  static const _loggerName = 'ThemeProvider';
  
  bool _isDark = true;
  bool _initialized = false;

  bool get isDark => _isDark;
  bool get isLight => !_isDark;
  bool get initialized => _initialized;

  ThemeProvider({bool initialDark = true}) {
    _isDark = initialDark;
  }

  /// Load theme preference from persistent storage.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDark = prefs.getBool(_themeKey);
      if (savedDark != null) {
        _isDark = savedDark;
        AppLogger.fine('Loaded theme: ${_isDark ? "dark" : "light"}', subsystem: _loggerName);
      }
      _initialized = true;
      notifyListeners();
    } catch (e, st) {
      AppLogger.severe('Failed to load theme preference', subsystem: _loggerName, error: e, stackTrace: st);
    }
  }

  /// Toggle between dark and light theme.
  void toggleTheme() {
    _isDark = !_isDark;
    _saveTheme();
    notifyListeners();
    AppLogger.info('Theme toggled to ${_isDark ? "dark" : "light"}', subsystem: _loggerName);
  }

  /// Set theme explicitly.
  void setTheme(bool dark) {
    if (_isDark != dark) {
      _isDark = dark;
      _saveTheme();
      notifyListeners();
      AppLogger.info('Theme set to ${_isDark ? "dark" : "light"}', subsystem: _loggerName);
    }
  }

  Future<void> _saveTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDark);
    } catch (e, st) {
      AppLogger.severe('Failed to save theme preference', subsystem: _loggerName, error: e, stackTrace: st);
    }
  }
}
