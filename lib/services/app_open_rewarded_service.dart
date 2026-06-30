import 'package:shared_preferences/shared_preferences.dart';


/// Service to show Unity Ads rewarded video on specific app opens (2nd, 4th, 6th, 8th - daily 4 bar).
class AppOpenRewardedService {
  AppOpenRewardedService._();
  static final AppOpenRewardedService instance = AppOpenRewardedService._();

  static const String _dailyAppOpenCountKey = 'daily_app_open_count';
  static const String _lastAppOpenDateKey = 'last_app_open_date';
  static const int _maxDailyRewardedOpens = 4;

  /// Track app open and determine if rewarded ad should show.
  /// Returns true if rewarded ad should be shown.
  Future<bool> onAppOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final lastDate = prefs.getString(_lastAppOpenDateKey);

    // Reset counter if new day
    if (lastDate != today) {
      await prefs.setInt(_dailyAppOpenCountKey, 0);
      await prefs.setString(_lastAppOpenDateKey, today);
    }

    final count = (prefs.getInt(_dailyAppOpenCountKey) ?? 0) + 1;
    await prefs.setInt(_dailyAppOpenCountKey, count);

    // Show rewarded on 2nd, 4th, 6th, 8th opens (max 4 per day)
    final shouldShow = count <= _maxDailyRewardedOpens && count % 2 == 0;

    if (shouldShow) {
      await _showRewardedAd();
    }

    return shouldShow;
  }

  Future<void> _showRewardedAd() async {
    try {
      // Unity Ads disabled - no rewarded ad shown
      // Silently fail - don't block app launch
    } catch (e) {
      // Silently fail - don't block app launch
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  /// Get today's app open count (for debugging/stats).
  Future<int> getTodayOpenCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final lastDate = prefs.getString(_lastAppOpenDateKey);

    if (lastDate != today) {
      return 0;
    }

    return prefs.getInt(_dailyAppOpenCountKey) ?? 0;
  }

  /// Reset daily counter (for testing).
  Future<void> resetDailyCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyAppOpenCountKey, 0);
  }
}
