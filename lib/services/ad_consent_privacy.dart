/// Consent flag mapping for ads consent (testable, no SDK calls).
///
/// Legacy: Previously used for LevelPlay privacy flags.
/// Unity Ads uses SharedPreferences directly via AdConsentService.
/// ISSUE: Remove if unused after Unity Ads migration complete.
/// See: https://github.com/your-repo/issues/XXX
class AdConsentPrivacyMapping {
  AdConsentPrivacyMapping._();

  /// Maps stored consent (`granted` | `denied` | null) to consent flags.
  /// Stub for future Unity Ads consent mapping.
  static ({bool gdprConsent, bool ccpaOptOut}) forConsent(String? consent) {
    switch (consent) {
      case 'granted':
        return (gdprConsent: true, ccpaOptOut: false);
      case 'denied':
        return (gdprConsent: false, ccpaOptOut: true);
      default:
        return (gdprConsent: false, ccpaOptOut: false);
    }
  }

  /// Before user chooses — restrictive defaults.
  /// Stub for future Unity Ads consent mapping.
  static ({bool gdprConsent, bool ccpaOptOut}) restrictiveDefaults() {
    return (gdprConsent: false, ccpaOptOut: false);
  }
}
