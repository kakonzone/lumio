import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'ad_safety_service.dart';

/// Referral code capture + optional server attribution.
class ReferralService {
  ReferralService._();
  static final ReferralService instance = ReferralService._();

  static const _prefCode = 'lumio_referral_code_v1';
  static const _prefRedeemed = 'lumio_referral_redeemed_v1';

  String? _code;
  bool _redeemed = false;

  String? get code => _code;
  bool get isRedeemed => _redeemed;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _code = prefs.getString(_prefCode);
    _redeemed = prefs.getBool(_prefRedeemed) ?? false;
  }

  Future<void> saveIncomingCode(String raw) async {
    final normalized = raw.trim().toUpperCase();
    if (normalized.length < 4) return;
    _code = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefCode, normalized);
    if (kDebugMode) debugPrint('[ReferralService] saved code=$normalized');
  }

  Future<bool> redeemBonus() async {
    if (_redeemed || _code == null || !AppConfig.hasBackend) return false;
    try {
      await AdSafetyService.instance.ensureReady();
      // Server endpoint documented in docs/BACKEND_WALLET_API.md
      if (!AppConfig.hasBackend) return false;
      _redeemed = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefRedeemed, true);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ReferralService] redeem failed: $e');
      return false;
    }
  }
}
