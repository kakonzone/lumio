// lib/services/cache_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/model.dart';

class CacheService {
  CacheService._();

  static const String _pfx = 'lumio_';
  static const String _tsSuffix = '_ts';

  static const String _keyChannels = '${_pfx}channels';
  static const String _keyMatches = '${_pfx}matches';
  static const String _keyNews = '${_pfx}news';
  static const String _keyLiveData = '${_pfx}live_data';
  static const String _keyPredictions = '${_pfx}predictions';

  static const Duration _ttlChannels = Duration(minutes: 10);
  static const Duration _ttlMatches = Duration(seconds: 60);
  static const Duration _ttlNews = Duration(minutes: 5);
  static const Duration _ttlLiveData = Duration(seconds: 30);
  static const Duration _ttlPredictions = Duration(minutes: 5);

  // ===========================================================================
  // CHANNELS
  // ===========================================================================

  // FIX: Channel → ChannelModel
  static Future<void> saveChannels(List<ChannelModel> channels) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(channels.map((c) => c.toJson()).toList());
      await prefs.setString(_keyChannels, payload);
      await _writeTimestamp(prefs, _keyChannels);
    } catch (e) {
      _log('saveChannels failed: $e');
    }
  }

  // FIX: Channel → ChannelModel
  static Future<List<ChannelModel>?> getCachedChannels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_isFresh(prefs, _keyChannels, _ttlChannels)) return null;
      final raw = prefs.getString(_keyChannels);
      if (raw == null) return null;
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((j) => ChannelModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log('getCachedChannels failed: $e');
      return null;
    }
  }

  // ===========================================================================
  // MATCHES
  // ===========================================================================

  static Future<void> saveMatches(List<MatchModel> matches,
      {String tag = 'all'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyMatches}_$tag';
      final payload = jsonEncode(matches.map((m) => m.toJson()).toList());
      await prefs.setString(key, payload);
      await _writeTimestamp(prefs, key);
    } catch (e) {
      _log('saveMatches($tag) failed: $e');
    }
  }

  static Future<List<MatchModel>?> getCachedMatches(
      {String tag = 'all'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyMatches}_$tag';
      if (!_isFresh(prefs, key, _ttlMatches)) return null;
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((j) => MatchModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log('getCachedMatches($tag) failed: $e');
      return null;
    }
  }

  // ===========================================================================
  // NEWS
  // ===========================================================================

  // FIX: NewsArticle → NewsModel
  static Future<void> saveNews(List<NewsModel> articles,
      {String category = 'all'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyNews}_$category';
      final payload = jsonEncode(articles.map((a) => a.toJson()).toList());
      await prefs.setString(key, payload);
      await _writeTimestamp(prefs, key);
    } catch (e) {
      _log('saveNews($category) failed: $e');
    }
  }

  // FIX: NewsArticle → NewsModel
  static Future<List<NewsModel>?> getCachedNews(
      {String category = 'all'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyNews}_$category';
      if (!_isFresh(prefs, key, _ttlNews)) return null;
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((j) => NewsModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log('getCachedNews($category) failed: $e');
      return null;
    }
  }

  // ===========================================================================
  // LIVE DATA
  // ===========================================================================

  static Future<void> saveLiveData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLiveData, jsonEncode(data));
      await _writeTimestamp(prefs, _keyLiveData);
    } catch (e) {
      _log('saveLiveData failed: $e');
    }
  }

  static Future<Map<String, dynamic>?> getCachedLiveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_isFresh(prefs, _keyLiveData, _ttlLiveData)) return null;
      final raw = prefs.getString(_keyLiveData);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      _log('getCachedLiveData failed: $e');
      return null;
    }
  }

  // ===========================================================================
  // PREDICTIONS
  // ===========================================================================

  static Future<void> savePredictions(List<MatchModel> predictions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(predictions.map((m) => m.toJson()).toList());
      await prefs.setString(_keyPredictions, payload);
      await _writeTimestamp(prefs, _keyPredictions);
    } catch (e) {
      _log('savePredictions failed: $e');
    }
  }

  static Future<List<MatchModel>?> getCachedPredictions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_isFresh(prefs, _keyPredictions, _ttlPredictions)) return null;
      final raw = prefs.getString(_keyPredictions);
      if (raw == null) return null;
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((j) => MatchModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log('getCachedPredictions failed: $e');
      return null;
    }
  }

  // ===========================================================================
  // CACHE CONTROL
  // ===========================================================================

  static Future<void> invalidate(CacheKey key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final resolved = _resolveKey(key);
      await prefs.remove(resolved);
      await prefs.remove('$resolved$_tsSuffix');
      _log('Invalidated: $resolved');
    } catch (e) {
      _log('invalidate(${key.name}) failed: $e');
    }
  }

  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys().where((k) => k.startsWith(_pfx)).toList();
      for (final k in allKeys) {
        await prefs.remove(k);
      }
      _log('All cache cleared (${allKeys.length} keys removed)');
    } catch (e) {
      _log('clearAll failed: $e');
    }
  }

  static Future<Duration?> cacheAge(CacheKey key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final resolved = _resolveKey(key);
      final tsKey = '$resolved$_tsSuffix';
      if (!prefs.containsKey(tsKey)) return null;
      final written = DateTime.fromMillisecondsSinceEpoch(prefs.getInt(tsKey)!);
      return DateTime.now().difference(written);
    } catch (e) {
      _log('cacheAge(${key.name}) failed: $e');
      return null;
    }
  }

  // ===========================================================================
  // PRIVATE HELPERS
  // ===========================================================================

  static Future<void> _writeTimestamp(
      SharedPreferences prefs, String key) async {
    await prefs.setInt(
      '$key$_tsSuffix',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static bool _isFresh(SharedPreferences prefs, String key, Duration ttl) {
    final tsKey = '$key$_tsSuffix';
    if (!prefs.containsKey(tsKey)) return false;
    final written = DateTime.fromMillisecondsSinceEpoch(prefs.getInt(tsKey)!);
    return DateTime.now().difference(written) < ttl;
  }

  static String _resolveKey(CacheKey key) {
    switch (key) {
      case CacheKey.channels:
        return _keyChannels;
      case CacheKey.matches:
        return _keyMatches;
      case CacheKey.news:
        return _keyNews;
      case CacheKey.liveData:
        return _keyLiveData;
      case CacheKey.predictions:
        return _keyPredictions;
    }
  }

  static void _log(String message) {
    assert(() {
      // ignore: avoid_print
      print('[CacheService] $message');
      return true;
    }());
  }
}

enum CacheKey {
  channels,
  matches,
  news,
  liveData,
  predictions,
}
