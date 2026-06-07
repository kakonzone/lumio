/// In-app sideload update — Appwrite Storage + `app_version` document (SGP).
class AppUpdateConfig {
  AppUpdateConfig._();

  static const endpoint = String.fromEnvironment(
    'APPWRITE_MAIN_ENDPOINT',
    defaultValue: 'https://sgp.cloud.appwrite.io/v1',
  );

  static const projectId = String.fromEnvironment(
    'APPWRITE_MAIN_PROJECT_ID',
    defaultValue: '6a22869200230b1a8bf0',
  );

  static const bucketId = String.fromEnvironment(
    'APPWRITE_APK_BUCKET_ID',
    defaultValue: 'lumio.apk',
  );

  static const databaseId = String.fromEnvironment(
    'APPWRITE_MAIN_DATABASE_ID',
    defaultValue: 'iptv_main',
  );

  static const collectionId = String.fromEnvironment(
    'APPWRITE_APP_VERSION_COLLECTION_ID',
    defaultValue: 'app_version',
  );

  static const versionDocumentId = String.fromEnvironment(
    'APPWRITE_VERSION_DOC_ID',
    defaultValue: '6a24675100155949547f',
  );

  static bool get isConfigured =>
      endpoint.isNotEmpty &&
      projectId.isNotEmpty &&
      bucketId.isNotEmpty &&
      databaseId.isNotEmpty &&
      collectionId.isNotEmpty &&
      versionDocumentId.isNotEmpty;
}
