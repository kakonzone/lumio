/// LUMIO নিরাপত্তা কনফিগ — রিলিজ বিল্ডের আগে এই মানগুলো আপডেট করুন।
///
/// **সেটআপ:**
/// 1. `expectedApkSignatureSha256` — রিলিজ কীস্টোর দিয়ে সাইন করা APK-র SHA-256:
///    `keytool -list -v -keystore your-release.jks -alias your_alias`
/// 2. `certificatePins` — ব্যাকএন্ড TLS সার্টিফিকেটের SHA-256 পিন (openssl):
///    `openssl s_client -connect api.example.com:443 | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64`
/// 3. `streamTokenEndpoint` — স্বাক্ষরিত স্ট্রিম URL দেয় এমন API (M3U8 সরাসরি ক্লায়েন্টে রাখবেন না)
class SecurityConfig {
  SecurityConfig._();

  /// ডিবাগ বিল্ডে নিরাপত্তা চেক বাইপাস (শুধু `kDebugMode`)
  static const bool bypassChecksInDebug = true;

  /// রিলিজে রুট/এমুলেটর/ডিবাগার/Frida ইত্যাদি পেলে অ্যাপ বন্ধ
  static const bool strictModeInRelease = true;

  /// `--dart-define=LUMIO_SIDELOAD_DEV=true` — local APK via adb (USB debugging on).
  static const bool sideloadDevBuild = bool.fromEnvironment(
    'LUMIO_SIDELOAD_DEV',
    defaultValue: false,
  );

  /// VPN ব্যবহারকারী ব্লক (অনেক লিগitimate ইউজার VPN ব্যবহার করে — ডিফল্ট false)
  static const bool blockVpn = false;

  /// HttpCanary, Magisk, PCAPdroid ইত্যাদি ইনস্টল থাকলে অ্যাপ চালু হবে না
  static const bool blockConflictingApps = true;

  /// Play Store ইনস্টল বাধ্য — রিলিজে `--dart-define=SECURITY_REQUIRE_PLAY_INSTALLER=true`
  static const bool requireKnownInstaller = bool.fromEnvironment(
    'SECURITY_REQUIRE_PLAY_INSTALLER',
    defaultValue: false,
  );

  /// অনুমোদিত ইনস্টলার প্যাকেজ (sideload হলে সাধারণত null বা ব্রাউজার)
  static const Set<String> allowedInstallers = {
    'com.android.vending',
    'com.google.android.packageinstaller',
  };

  /// রিলিজ APK সাইনিং সার্টিফিকেট SHA-256 (কলোন ছাড়া, uppercase hex)
  /// খালি রাখলে সিগনেচার চেক স্কিপ হয়।
  static const String expectedApkSignatureSha256 = '';

  /// API বেস URL — প্রোডাকশনে নেটিভ লেয়ার বা এনভ থেকে নিন
  static const String apiBaseUrl = String.fromEnvironment(
    'LUMIO_API_BASE',
    defaultValue: 'https://api.example.com',
  );

  /// স্বাক্ষরিত স্ট্রিম টোকেন এন্ডপয়েন্ট
  static const String streamTokenPath = '/v1/stream/token';

  /// Global stream/API pins (fallback when host-specific stream token pins unset).
  static const String sslPinPrimary = String.fromEnvironment(
    'SSL_PIN_PRIMARY',
    defaultValue: '__MISSING__',
  );
  static const String sslPinBackup = String.fromEnvironment(
    'SSL_PIN_BACKUP',
    defaultValue: '__MISSING__',
  );

  /// TLS pinning targets (host -> primary/backup pins via dart-define).
  static const String streamTokenPinPrimary = String.fromEnvironment(
    'SSL_PIN_STREAM_TOKEN_PRIMARY',
    defaultValue: '__MISSING__',
  );
  static const String streamTokenPinBackup = String.fromEnvironment(
    'SSL_PIN_STREAM_TOKEN_BACKUP',
    defaultValue: '__MISSING__',
  );
  // LevelPlay pins removed during deprecation
  static const String supersonicPinPrimary = String.fromEnvironment(
    'SSL_PIN_SUPERSONIC_PRIMARY',
    defaultValue: '__MISSING__',
  );
  static const String supersonicPinBackup = String.fromEnvironment(
    'SSL_PIN_SUPERSONIC_BACKUP',
    defaultValue: '__MISSING__',
  );
  static const String adsterraPinPrimary = String.fromEnvironment(
    'SSL_PIN_ADSTERRA_PRIMARY',
    defaultValue: '__MISSING__',
  );
  static const String adsterraPinBackup = String.fromEnvironment(
    'SSL_PIN_ADSTERRA_BACKUP',
    defaultValue: '__MISSING__',
  );

  static List<String> _pins(String primary, String backup) => [
        if (primary.trim().isNotEmpty && primary != '__MISSING__')
          primary.trim(),
        if (backup.trim().isNotEmpty && backup != '__MISSING__') backup.trim(),
      ];

  static Map<String, List<String>> get hostPins => {
        // LevelPlay pins removed during deprecation
        'init.supersonic.com': _pins(
          supersonicPinPrimary,
          supersonicPinBackup,
        ),
        'adsterra.com': _pins(adsterraPinPrimary, adsterraPinBackup),
      };

  static List<String> get streamTokenPins {
    final specific = _pins(streamTokenPinPrimary, streamTokenPinBackup);
    if (specific.isNotEmpty) return specific;
    return _pins(sslPinPrimary, sslPinBackup);
  }

  /// HMAC রিকোয়েস্ট সাইনিং সিক্রেট (সার্ভারের সাথে মিলিয়ে রাখুন)
  static const String hmacSecret = String.fromEnvironment(
    'LUMIO_HMAC_SECRET',
    defaultValue: '',
  );

  /// রিকোয়েস্ট টাইমস্ট্যাম্প উইন্ডো
  static const Duration requestTimestampSkew = Duration(seconds: 30);

  /// পটভূমিতে পুনরায় চেকের ব্যবধান
  static const Duration watchdogInterval = Duration(seconds: 60);
}
