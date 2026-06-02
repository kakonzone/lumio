import 'package:shared_preferences/shared_preferences.dart';

/// Cold-start session counter (for push permission on Nth open).
class AppSessionTracker {
  AppSessionTracker._();
  static final AppSessionTracker instance = AppSessionTracker._();

  static const _keySessionCount = 'lumio_app_session_count';

  int _sessionNumber = 0;
  bool _loaded = false;

  Future<void> onAppLaunch() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final n = (prefs.getInt(_keySessionCount) ?? 0) + 1;
    await prefs.setInt(_keySessionCount, n);
    _sessionNumber = n;
    _loaded = true;
  }

  int get sessionNumber => _sessionNumber;
}
