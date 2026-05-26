import 'dart:collection';

import '../ad_log.dart';
import '../../services/ad_consent_service.dart';

/// In-memory LRU cache for Adsterra native/banner HTML by placement id.
class AdsterraNativeCache {
  AdsterraNativeCache._();
  static final AdsterraNativeCache instance = AdsterraNativeCache._();

  static const Duration _ttl = Duration(minutes: 5);
  static const int _maxEntries = 20;

  final LinkedHashMap<String, _CachedAd> _entries = LinkedHashMap();
  int _hits = 0;
  int _misses = 0;

  int get hits => _hits;
  int get misses => _misses;

  double get hitRate {
    final total = _hits + _misses;
    if (total == 0) return 0;
    return _hits / total;
  }

  /// Returns cached HTML when fresh; otherwise null.
  String? get(String placementId) {
    final entry = _entries[placementId];
    if (entry == null) {
      _misses++;
      adLog('[AdsterraCache] miss placement=$placementId');
      return null;
    }
    if (DateTime.now().difference(entry.storedAt) > _ttl) {
      _entries.remove(placementId);
      _misses++;
      adLog('[AdsterraCache] miss placement=$placementId reason=expired');
      return null;
    }
    _hits++;
    _entries.remove(placementId);
    _entries[placementId] = entry;
    adLog('[AdsterraCache] hit placement=$placementId');
    return entry.html;
  }

  void put(String placementId, String html) {
    if (placementId.isEmpty || html.isEmpty) return;
    _entries.remove(placementId);
    _entries[placementId] = _CachedAd(html: html, storedAt: DateTime.now());
    while (_entries.length > _maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  /// Cleared when user revokes ad consent.
  void clear() {
    _entries.clear();
    _hits = 0;
    _misses = 0;
    adLog('[AdsterraCache] cleared');
  }

  static void registerConsentListener() {
    AdConsentService.instance.addRevokeListener(() {
      instance.clear();
    });
  }
}

class _CachedAd {
  _CachedAd({required this.html, required this.storedAt});

  final String html;
  final DateTime storedAt;
}
