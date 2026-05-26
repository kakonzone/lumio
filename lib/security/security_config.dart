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

  /// VPN ব্যবহারকারী ব্লক (অনেক লিগitimate ইউজার VPN ব্যবহার করে — ডিফল্ট false)
  static const bool blockVpn = false;

  /// অজানা ইনস্টলার (Play Store ছাড়া sideload) ব্লক
  static const bool requireKnownInstaller = false;

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

  /// TLS সার্টিফিকেট পিন (Base64 SHA-256 SPKI) — খালি = শুধু সিস্টেম CA
  static const List<String> certificatePins = <String>[
    // 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  ];

  /// ব্যাকআপ পিন (সার্ট রোটেশনের জন্য)
  static const List<String> certificateBackupPins = <String>[];

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
