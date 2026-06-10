import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_log.dart';

/// Global impression deduplication to prevent ad replay within time window.
/// Fingerprint = SHA256(placement_id + network + adUnitId)
/// Time window: 5 min per placement
class ImpressionDedup {
  ImpressionDedup._();
  static final ImpressionDedup instance = ImpressionDedup._();

  static const String _impressionsKey = 'impression_dedup_log';
  static const Duration _dedupWindow = Duration(minutes: 5);

  /// Record an impression. Returns true if this is a new impression (not deduped).
  Future<bool> recordImpression({
    required String placementId,
    required String network,
    required String adUnitId,
  }) async {
    final fingerprint = _generateFingerprint(
      placementId: placementId,
      network: network,
      adUnitId: adUnitId,
    );

    final prefs = await SharedPreferences.getInstance();
    final impressions = _loadImpressions(prefs);

    // Check if this fingerprint exists within the time window
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - _dedupWindow.inMilliseconds;

    // Remove expired entries
    impressions.removeWhere((key, timestamp) => timestamp < cutoff);

    // Check if this fingerprint already exists
    if (impressions.containsKey(fingerprint)) {
      adLog('[ImpressionDedup] deduped: $network/$adUnitId at $placementId');
      return false;
    }

    // Record new impression
    impressions[fingerprint] = now;
    await _saveImpressions(prefs, impressions);

    adLog('[ImpressionDedup] recorded: $network/$adUnitId at $placementId');
    return true;
  }

  /// Generate SHA256 fingerprint from placement, network, and ad unit ID.
  String _generateFingerprint({
    required String placementId,
    required String network,
    required String adUnitId,
  }) {
    final input = '$placementId|$network|$adUnitId';
    final bytes = utf8.encode(input);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Load impressions from SharedPreferences.
  Map<String, int> _loadImpressions(SharedPreferences prefs) {
    final json = prefs.getString(_impressionsKey);
    if (json == null || json.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value as int));
    } catch (e) {
      adLog('[ImpressionDedup] failed to load impressions: $e');
      return {};
    }
  }

  /// Save impressions to SharedPreferences.
  Future<void> _saveImpressions(
    SharedPreferences prefs,
    Map<String, int> impressions,
  ) async {
    try {
      final json = jsonEncode(impressions);
      await prefs.setString(_impressionsKey, json);
    } catch (e) {
      adLog('[ImpressionDedup] failed to save impressions: $e');
    }
  }

  /// Clear all impression records (for testing).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_impressionsKey);
    adLog('[ImpressionDedup] cleared all records');
  }

  /// Get count of active impression records (within time window).
  Future<int> getActiveCount() async {
    final prefs = await SharedPreferences.getInstance();
    final impressions = _loadImpressions(prefs);

    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - _dedupWindow.inMilliseconds;

    return impressions.values.where((timestamp) => timestamp >= cutoff).length;
  }

  /// Check if a specific impression would be deduped (without recording).
  Future<bool> wouldDedup({
    required String placementId,
    required String network,
    required String adUnitId,
  }) async {
    final fingerprint = _generateFingerprint(
      placementId: placementId,
      network: network,
      adUnitId: adUnitId,
    );

    final prefs = await SharedPreferences.getInstance();
    final impressions = _loadImpressions(prefs);

    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - _dedupWindow.inMilliseconds;

    // Remove expired entries for accurate check
    impressions.removeWhere((key, timestamp) => timestamp < cutoff);

    return impressions.containsKey(fingerprint);
  }
}
