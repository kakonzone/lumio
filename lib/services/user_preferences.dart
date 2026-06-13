import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_constants.dart';

/// Ad-free purchase flag and per-channel first-tap browser state.
class UserPreferences {
  UserPreferences._();
  static SharedPreferences? _prefs;

  static Future<void> ensureInit() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get p {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('Call UserPreferences.ensureInit() first');
    }
    return prefs;
  }

  static bool get removeAdsPurchased =>
      p.getBool(AppConstants.prefRemoveAdsPurchased) ?? false;

  static Future<void> setRemoveAdsPurchased(bool v) =>
      p.setBool(AppConstants.prefRemoveAdsPurchased, v);

  static DateTime? get adFreeUntil {
    final ms = p.getInt(AppConstants.prefAdFreeUntil);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> setAdFreeUntil(DateTime until) =>
      p.setInt(AppConstants.prefAdFreeUntil, until.millisecondsSinceEpoch);

  /// Per-channel taps today (0 = never tapped today).
  static int channelTapCount(String channelKey) {
    _syncChannelClickDay();
    return p.getInt('${AppConstants.prefChannelClickPrefix}$channelKey') ?? 0;
  }

  static void _syncChannelClickDay() {
    final dayKey = _todayKey();
    final storedDay = p.getString(AppConstants.prefChannelClickDay);
    if (storedDay != dayKey) {
      p.setString(AppConstants.prefChannelClickDay, dayKey);
      final keys = p.getKeys().where(
            (k) =>
                k.startsWith(AppConstants.prefChannelClickPrefix) &&
                k != AppConstants.prefChannelClickDay,
          );
      for (final k in keys) {
        p.remove(k);
      }
    }
  }

  /// First tap on this channel today → show ad; returns false on 2nd+ tap.
  static Future<bool> shouldShowFirstChannelTapAd(String channelKey) async {
    _syncChannelClickDay();
    final count =
        p.getInt('${AppConstants.prefChannelClickPrefix}$channelKey') ?? 0;
    if (count == 0) {
      await p.setInt(
        '${AppConstants.prefChannelClickPrefix}$channelKey',
        1,
      );
      return true;
    }
    await p.setInt(
      '${AppConstants.prefChannelClickPrefix}$channelKey',
      count + 1,
    );
    return false;
  }

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }
}
