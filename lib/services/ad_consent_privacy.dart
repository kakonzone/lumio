/// Consent flag mapping for ads consent (testable, no SDK calls).
///
/// Previously used for LevelPlay privacy flags.
/// TODO: Update for Unity Ads consent mechanism when available.
class AdConsentPrivacyMapping {
  AdConsentPrivacyMapping._();

  /// Maps stored consent (`granted` | `denied` | null) to consent flags.
  /// Stub for future Unity Ads consent mapping.
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

  /// Before user chooses — restrictive defaults.
  /// Stub for future Unity Ads consent mapping.
  static ({bool gdprLevelPlay, bool ccpaOptOut}) restrictiveDefaults() {
    return (gdprLevelPlay: false, ccpaOptOut: false);
  }
}
