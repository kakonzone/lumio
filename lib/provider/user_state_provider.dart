import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme + favorites (extracted from [AppProvider]).
class UserStateProvider extends ChangeNotifier {
  static const _favoritesKey = 'lumio_favorite_channel_ids';

  final Set<String> _favoriteIds = {};
  bool _isDark = true;

  int get favoriteCount => _favoriteIds.length;
  bool get isDark => _isDark;
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

  bool isFavorite(String channelId) => _favoriteIds.contains(channelId);

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }

  Future<void> loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_favoritesKey) ?? [];
      _favoriteIds
        ..clear()
        ..addAll(ids);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> addFavoriteId(String channelId) async {
    if (channelId.isEmpty) return;
    _favoriteIds.add(channelId);
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> removeFavoriteId(String channelId) async {
    _favoriteIds.remove(channelId);
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoritesKey, _favoriteIds.toList());
    } catch (_) {}
  }
}
