import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/model.dart';
import '../../utils/app_logger.dart';

/// Favorites management provider.
/// 
/// Handles user's favorite channels with persistence.
/// Separate from theme to allow granular UI updates.
class FavoritesProvider extends ChangeNotifier {
  static const _favoritesKey = 'lumio_favorite_channel_ids';
  static const _loggerName = 'FavoritesProvider';
  
  final Set<String> _favoriteIds = {};
  bool _initialized = false;

  int get favoriteCount => _favoriteIds.length;
  bool get initialized => _initialized;
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

  FavoritesProvider();

  bool isFavorite(String channelId) => _favoriteIds.contains(channelId);

  /// Load favorites from persistent storage.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_favoritesKey) ?? [];
      _favoriteIds
        ..clear()
        ..addAll(ids);
      _initialized = true;
      notifyListeners();
      AppLogger.fine('Loaded ${ids.length} favorites', subsystem: _loggerName);
    } catch (e, st) {
      AppLogger.severe('Failed to load favorites', subsystem: _loggerName, error: e, stackTrace: st);
    }
  }

  /// Add a channel to favorites.
  Future<void> addFavorite(String channelId) async {
    if (channelId.isEmpty) return;
    if (_favoriteIds.add(channelId)) {
      await _saveFavorites();
      notifyListeners();
      AppLogger.info('Added favorite: $channelId', subsystem: _loggerName);
    }
  }

  /// Add a channel model to favorites.
  Future<void> addFavoriteChannel(ChannelModel channel) async {
    await addFavorite(channel.id);
  }

  /// Remove a channel from favorites.
  Future<void> removeFavorite(String channelId) async {
    if (_favoriteIds.remove(channelId)) {
      await _saveFavorites();
      notifyListeners();
      AppLogger.info('Removed favorite: $channelId', subsystem: _loggerName);
    }
  }

  /// Toggle favorite status for a channel.
  Future<void> toggleFavorite(String channelId) async {
    if (isFavorite(channelId)) {
      await removeFavorite(channelId);
    } else {
      await addFavorite(channelId);
    }
  }

  /// Get favorite channels from a list of all channels.
  List<ChannelModel> getFavoriteChannels(List<ChannelModel> allChannels) {
    final list = allChannels.where((c) => _favoriteIds.contains(c.id)).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// Clear all favorites.
  Future<void> clearAll() async {
    if (_favoriteIds.isNotEmpty) {
      _favoriteIds.clear();
      await _saveFavorites();
      notifyListeners();
      AppLogger.warning('Cleared all favorites', subsystem: _loggerName);
    }
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoritesKey, _favoriteIds.toList());
    } catch (e, st) {
      AppLogger.severe('Failed to save favorites', subsystem: _loggerName, error: e, stackTrace: st);
    }
  }
}
