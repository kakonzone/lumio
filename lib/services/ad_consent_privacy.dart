/// LevelPlay privacy flag mapping for ads consent (testable, no SDK calls).
///
/// LevelPlay 9.2.0 semantics:
/// - [gdprLevelPlay] `true` = consent **granted** for personalized ads.
/// - [ccpaOptOut] `true` = user **opted out** of sale (CCPA).
class AdConsentPrivacyMapping {
  AdConsentPrivacyMapping._();

  /// Maps stored consent (`granted` | `denied` | null) to SDK flags.
  static ({bool gdprLevelPlay, bool ccpaOptOut}) forConsent(String? consent) {
    switch (consent) {
      case 'granted':
        return (gdprLevelPlay: true, ccpaOptOut: false);
      case 'denied':
        return (gdprLevelPlay: false, ccpaOptOut: true);
      default:
        return (gdprLevelPlay: false, ccpaOptOut: false);
    }
  }

  /// Before user chooses — restrictive (no sale opt-out flag until Limited is chosen).
  static ({bool gdprLevelPlay, bool ccpaOptOut}) restrictiveDefaults() {
    return (gdprLevelPlay: false, ccpaOptOut: false);
  }
}
