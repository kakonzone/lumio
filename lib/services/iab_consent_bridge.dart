import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight IAB TCF string storage until a full CMP SDK is integrated.
///
/// Stores publisher consent choices for analytics and future UMP wiring.
class IabConsentBridge {
  IabConsentBridge._();
  static final IabConsentBridge instance = IabConsentBridge._();

  static const _prefTcString = 'lumio_iab_tc_string_v1';
  static const _prefGdprApplies = 'lumio_iab_gdpr_applies_v1';

  String? _tcString;
  bool? _gdprApplies;

  String? get tcString => _tcString;
  bool? get gdprApplies => _gdprApplies;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _tcString = prefs.getString(_prefTcString);
    _gdprApplies = prefs.getBool(_prefGdprApplies);
  }

  Future<void> saveTcString(String value, {bool? gdprApplies}) async {
    _tcString = value.trim().isEmpty ? null : value.trim();
    if (gdprApplies != null) _gdprApplies = gdprApplies;
    final prefs = await SharedPreferences.getInstance();
    if (_tcString == null) {
      await prefs.remove(_prefTcString);
    } else {
      await prefs.setString(_prefTcString, _tcString!);
    }
    if (_gdprApplies != null) {
      await prefs.setBool(_prefGdprApplies, _gdprApplies!);
    }
    if (kDebugMode) {
      debugPrint('[IabConsentBridge] TC string saved (len=${_tcString?.length ?? 0})');
    }
  }

  Future<void> clear() async {
    _tcString = null;
    _gdprApplies = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefTcString);
    await prefs.remove(_prefGdprApplies);
  }
}
