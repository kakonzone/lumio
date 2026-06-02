import 'package:flutter/foundation.dart';

import '../services/user_preferences.dart';

/// Client-side ad-free window state (e.g. remove-ads purchase).
class AdGateProvider extends ChangeNotifier {
  bool get removeAdsPurchased => UserPreferences.removeAdsPurchased;

  bool get isAdFreeActive {
    final until = UserPreferences.adFreeUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  Future<void> grantAdFreeMinutes(int minutes) async {
    await UserPreferences.setAdFreeUntil(
      DateTime.now().add(Duration(minutes: minutes)),
    );
    notifyListeners();
  }

  Future<void> refresh() async {
    notifyListeners();
  }
}
