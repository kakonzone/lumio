import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Encrypted install ID on Android (EncryptedSharedPreferences via native channel).
///
/// iOS/desktop: no-op read/write — install ID stays in [SharedPreferences] only.
class SecureInstallIdStore {
  SecureInstallIdStore._();
  static final SecureInstallIdStore instance = SecureInstallIdStore._();

  static const _channel = MethodChannel('com.lumio.security/native');

  Future<String?> read() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('readEncryptedInstallId');
    } catch (e) {
      if (kDebugMode) debugPrint('[SecureInstallId] read failed: $e');
      return null;
    }
  }

  Future<void> write(String installId) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(
        'writeEncryptedInstallId',
        {'installId': installId},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[SecureInstallId] write failed: $e');
    }
  }
}
