/// Public legal URLs — override via `--dart-define` in CI (see `docs/BUILD.md`).
class LegalConfig {
  LegalConfig._();

  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://lumio.app/privacy',
  );
  static const String termsOfServiceUrl = String.fromEnvironment(
    'TERMS_OF_SERVICE_URL',
    defaultValue: 'https://lumio.app/terms',
  );
  static const String contactEmail = String.fromEnvironment(
    'CONTACT_EMAIL',
    defaultValue: 'support@lumio.app',
  );
  static const String dataDeletionUrl = String.fromEnvironment(
    'DATA_DELETION_URL',
    defaultValue: 'https://lumio.app/data-deletion',
  );

  static bool get hasPrivacyPolicy => privacyPolicyUrl.trim().isNotEmpty;
  static bool get hasTerms => termsOfServiceUrl.trim().isNotEmpty;
  static bool get hasContactEmail => contactEmail.trim().isNotEmpty;
  static bool get hasDataDeletion => dataDeletionUrl.trim().isNotEmpty;
}
