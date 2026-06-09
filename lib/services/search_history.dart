// lib/services/search_history.dart
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing search history with SharedPreferences.
/// 
/// Features:
/// - Max 10 recent searches
/// - Deduplication (adding existing query moves it to top)
/// - Persistent storage
class SearchHistory {
  static const String _key = 'search_history';
  static const int _maxItems = 10;

  /// Get all recent searches
  static Future<List<String>> getRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_key) ?? [];
    return history;
  }

  /// Add a query to search history
  /// 
  /// Moves existing query to top if already present
  /// Maintains max 10 items
  static Future<void> add(String query) async {
    if (query.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final history = await getRecent();

    // Remove if already exists (for deduplication)
    history.remove(query);

    // Add to front
    history.insert(0, query);

    // Trim to max 10
    if (history.length > _maxItems) {
      history.removeRange(_maxItems, history.length);
    }

    await prefs.setStringList(_key, history);
  }

  /// Remove a specific query from history
  static Future<void> remove(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getRecent();
    history.remove(query);
    await prefs.setStringList(_key, history);
  }

  /// Clear all search history
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Check if history is empty
  static Future<bool> isEmpty() async {
    final history = await getRecent();
    return history.isEmpty;
  }
}