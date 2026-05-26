import 'package:flutter/services.dart';

/// Android নেটিভ নিরাপত্তা ব্রিজ (`com.lumio.security/native`)
class SecurityNative {
  SecurityNative._();

  static const MethodChannel _channel =
      MethodChannel('com.lumio.security/native');

  static bool? _nativeAvailable;

  /// `false` when `liblumio_security.so` failed to load (Dart-only security path).
  static Future<bool> isNativeSecurityAvailable() async {
    if (_nativeAvailable != null) return _nativeAvailable!;
    try {
      final v = await _channel.invokeMethod<bool>('isNativeSecurityAvailable');
      _nativeAvailable = v ?? false;
      return _nativeAvailable!;
    } on PlatformException {
      _nativeAvailable = false;
      return false;
    }
  }

  /// APK সাইনিং সার্টিফিকেট SHA-256 (hex, uppercase)
  static Future<String?> getApkSignatureSha256() async {
    try {
      final result = await _channel.invokeMethod<String>('getApkSignatureSha256');
      return result?.toUpperCase();
    } on PlatformException {
      return null;
    }
  }

  /// নেটিভ লেয়ার থেকে ডিক্রিপ্ট করা সিক্রেট (ডিভাইস যাচাই পাস হলে)
  static Future<String?> getNativeSecret(String key) async {
    try {
      return await _channel.invokeMethod<String>('getNativeSecret', {
        'key': key,
      });
    } on PlatformException {
      return null;
    }
  }

  /// নেটিভ anti-tamper / ptrace স্ট্যাটাস
  static Future<bool> nativeIntegrityOk() async {
    try {
      final ok = await _channel.invokeMethod<bool>('nativeIntegrityOk');
      return ok ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Kotlin-সাইড এমুলেটর হিউরিস্টিক
  static Future<bool> isEmulatorNative() async {
    try {
      final v = await _channel.invokeMethod<bool>('isEmulator');
      return v ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// USB ডিবাগিং চালু আছে কিনা
  static Future<bool> isAdbDebuggingEnabled() async {
    try {
      final v = await _channel.invokeMethod<bool>('isAdbDebuggingEnabled');
      return v ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// ইনস্টলার প্যাকেজ নাম
  static Future<String?> getInstallerPackageName() async {
    try {
      return await _channel.invokeMethod<String>('getInstallerPackageName');
    } on PlatformException {
      return null;
    }
  }

  /// VPN signals for [SecurityManager] (tun/transport/ASN proxy).
  static Future<SecurityVpnSignals> collectVpnSecurity() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'collectVpnSecurity',
      );
      if (raw == null) return const SecurityVpnSignals();
      return SecurityVpnSignals(
        vpnDetected: raw['vpnDetected'] == true,
        vpnInterface: raw['vpnInterface'] == true,
        vpnTransport: raw['vpnTransport'] == true,
        asnMatched: raw['asnMatched'] == true,
        reason: raw['reason'] as String? ?? '',
      );
    } on PlatformException {
      return const SecurityVpnSignals();
    }
  }
}

/// Native VPN check payload for security gating.
class SecurityVpnSignals {
  const SecurityVpnSignals({
    this.vpnDetected = false,
    this.vpnInterface = false,
    this.vpnTransport = false,
    this.asnMatched = false,
    this.reason = '',
  });

  final bool vpnDetected;
  final bool vpnInterface;
  final bool vpnTransport;
  final bool asnMatched;
  final String reason;
}
