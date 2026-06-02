/// Public legal page URLs (GitHub Pages default; override via `--dart-define`).
class LegalUrls {
  LegalUrls._();

  static const String kPrivacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://kakonzone.github.io/lumio/privacy.html',
  );

  static const String kTermsOfServiceUrl = String.fromEnvironment(
    'TERMS_OF_SERVICE_URL',
    defaultValue: 'https://kakonzone.github.io/lumio/terms.html',
  );

  static const String kContactEmail = String.fromEnvironment(
    'CONTACT_EMAIL',
    defaultValue: 'legal@lumio.app',
  );

  static const String kDataDeletionUrl = String.fromEnvironment(
    'DATA_DELETION_URL',
    defaultValue: 'https://kakonzone.github.io/lumio/data-deletion.html',
  );
}
