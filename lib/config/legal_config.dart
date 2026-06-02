import '../core/constants/legal_urls.dart';

/// Public legal URLs — override via `--dart-define` in CI (see `docs/BUILD.md`).
class LegalConfig {
  LegalConfig._();

  static const String privacyPolicyUrl = LegalUrls.kPrivacyPolicyUrl;
  static const String termsOfServiceUrl = LegalUrls.kTermsOfServiceUrl;
  static const String contactEmail = LegalUrls.kContactEmail;
  static const String dataDeletionUrl = LegalUrls.kDataDeletionUrl;

  static bool get hasPrivacyPolicy => privacyPolicyUrl.trim().isNotEmpty;
  static bool get hasTerms => termsOfServiceUrl.trim().isNotEmpty;
  static bool get hasContactEmail => contactEmail.trim().isNotEmpty;
  static bool get hasDataDeletion => dataDeletionUrl.trim().isNotEmpty;
}
