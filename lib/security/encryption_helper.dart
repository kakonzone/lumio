import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// AES/HMAC ইউটিলিটি — সংবেদনশীল স্ট্রিং ও রিকোয়েস্ট বডি এনক্রিপ্ট।
///
/// **ব্যবহার:** বিল্ড টাইমে `tool/encrypt_strings.dart` দিয়ে স্ট্রিং এনক্রিপ্ট করে
/// `EncryptedSecrets` ক্লাসে রাখুন; রানটাইমে `decryptPrefixed` দিয়ে ডিক্রিপ্ট করুন।
class EncryptionHelper {
  EncryptionHelper._();

  static final Random _rng = Random.secure();

  /// AES-256-CBC এনক্রিপ্ট — ফরম্যাট: `lumio1:` + base64(IV + ciphertext)
  static String encryptAesCbc(String plaintext, List<int> key32) {
    if (key32.length != 32) {
      throw ArgumentError('AES-256 key must be 32 bytes');
    }
    final key = enc.Key(Uint8List.fromList(key32));
    final iv = enc.IV.fromSecureRandom(16);
    final aes = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = aes.encrypt(plaintext, iv: iv);
    final payload = Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
    return 'lumio1:${base64Encode(payload)}';
  }

  /// AES-256-CBC ডিক্রিপ্ট
  static String decryptAesCbc(String sealed, List<int> key32) {
    if (!sealed.startsWith('lumio1:')) {
      throw FormatException('Unknown seal prefix');
    }
    if (key32.length != 32) {
      throw ArgumentError('AES-256 key must be 32 bytes');
    }
    final raw = base64Decode(sealed.substring(7));
    if (raw.length < 17) throw FormatException('Payload too short');
    final iv = enc.IV(raw.sublist(0, 16));
    final cipher = enc.Encrypted(raw.sublist(16));
    final key = enc.Key(Uint8List.fromList(key32));
    final aes = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return aes.decrypt(cipher, iv: iv);
  }

  /// HMAC-SHA256 (hex) — API রিকোয়েস্ট সাইনিং
  static String hmacSha256Hex(String message, String secret) {
    final mac = Hmac(sha256, utf8.encode(secret));
    return mac.convert(utf8.encode(message)).toString();
  }

  /// রিকোয়েস্ট সাইনিং পেলোড: `timestamp|nonce|method|path|bodyHash`
  static String buildSigningPayload({
    required int timestampMs,
    required String nonce,
    required String method,
    required String path,
    required String body,
  }) {
    final bodyHash = sha256.convert(utf8.encode(body)).toString();
    return '$timestampMs|$nonce|$method|$path|$bodyHash';
  }

  /// ক্রিপ্টোগ্রাফিক নন্স
  static String randomNonce([int byteLength = 16]) {
    final bytes = List<int>.generate(byteLength, (_) => _rng.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// XOR অবফাসকেশন (নেটিভ লেয়ারের মতো সহজ স্ট্রিং লুকানো)
  static String xorDecode(List<int> data, int keyByte) {
    return String.fromCharCodes(data.map((b) => b ^ keyByte));
  }

  /// মেমরি থেকে সংবেদনশীল স্ট্রিং মুছে ফেলা (best-effort)
  static void wipeString(String? value) {
    // Dart String immutable — শুধু রেফারেন্স ছাড়ার জন্য; গুরুত্বপূর্ণ ডেটা char buffer এ রাখুন
    if (value == null) return;
    // ignore: unused_local_variable
    final _ = value.length;
  }

  /// পাসফ্রেজ থেকে 32-বাইট কী (PBKDF2 সহজ ভেরিয়েন্ট — প্রোডাকশনে নেটিভ KDF ভালো)
  static List<int> deriveKey32(String passphrase, {List<int>? salt}) {
    final s = salt ?? utf8.encode('lumio_salt_v1');
    List<int> block = utf8.encode(passphrase);
    for (var i = 0; i < 12000; i++) {
      block = sha256.convert([...block, ...s]).bytes;
    }
    return block.sublist(0, 32);
  }
}

/// বিল্ড-টাইম এনক্রিপ্ট করা স্ট্রিং (উদাহরণ — `tool/encrypt_strings.dart` জেনারেট করবে)
class EncryptedSecrets {
  EncryptedSecrets._();

  /// উদাহরণ: API হোস্ট — প্রোডাকশনে জেনারেটেড বাইট অ্যারে বসান
  static const List<int> _sampleXorPayload = <int>[];
  static const int _sampleXorKey = 0x5A;

  static String? sampleApiHost() {
    if (_sampleXorPayload.isEmpty) return null;
    return EncryptionHelper.xorDecode(_sampleXorPayload, _sampleXorKey);
  }
}
