import 'package:flutter/foundation.dart';

import '../services/ad_consent_service.dart';
import '../services/iab_consent_bridge.dart';

/// Ads privacy / consent settings exposed to settings screens.
class AdsSettingsProvider extends ChangeNotifier {
  bool _loaded = false;

  bool get loaded => _loaded;
  bool get needsConsent => AdConsentService.instance.needsConsentPrompt;
  bool get adsGranted => AdConsentService.instance.hasGrantedConsent;
  String? get tcfConsentString => IabConsentBridge.instance.tcString;

  Future<void> load() async {
    await AdConsentService.instance.load();
    await IabConsentBridge.instance.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setAdsConsent(bool granted) async {
    await AdConsentService.instance.setConsent(granted: granted);
    notifyListeners();
  }
}
