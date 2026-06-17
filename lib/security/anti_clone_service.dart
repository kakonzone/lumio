import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'security_config.dart';
import 'security_native.dart';
import 'play_integrity_service.dart';

/// Anti-clone verification service
///
/// Combines multiple security checks to prevent app cloning:
/// - Play Integrity API verification
/// - APK signature verification
/// - Package name verification
/// - Root/jailbreak detection
class AntiCloneService {
  AntiCloneService._();
  static final AntiCloneService instance = AntiCloneService._();

  static const _channel = MethodChannel('com.lumio.security/native');

  bool _isInitialized = false;
  bool _lastVerificationPassed = false;
  DateTime? _lastVerificationTime;
  String? _currentPackageName;
  String? _currentSignature;

  /// Initialize all security services
  Future<bool> initialize() async {
    if (_isInitialized) return _lastVerificationPassed;

    if (kDebugMode && SecurityConfig.bypassChecksInDebug) {
      _isInitialized = true;
      _lastVerificationPassed = true;
      debugPrint('[AntiClone] Security checks bypassed in debug mode');
      return true;
    }

    try {
      // Initialize Play Integrity API
      await PlayIntegrityService.instance.initialize();

      // Get current package info
      _currentPackageName = await _getPackageName();
      _currentSignature = await _getApkSignature();

      debugPrint('[AntiClone] Package: $_currentPackageName');
      debugPrint('[AntiClone] Signature: ${_currentSignature?.substring(0, 8)}...');

      _isInitialized = true;
      
      // Perform initial verification
      _lastVerificationPassed = await verifyAll();
      _lastVerificationTime = DateTime.now();

      if (!_lastVerificationPassed) {
        debugPrint('[AntiClone] Initial verification failed');
      }

      return _lastVerificationPassed;
    } catch (e) {
      debugPrint('[AntiClone] Initialization error: $e');
      _isInitialized = true;
      _lastVerificationPassed = false;
      return false;
    }
  }

  /// Perform comprehensive verification
  Future<bool> verifyAll() async {
    if (kDebugMode && SecurityConfig.bypassChecksInDebug) {
      return true;
    }

    if (!_isInitialized) {
      await initialize();
    }

    final results = await Future.wait<bool>([
      _verifyPackageName(),
      _verifyApkSignature(),
      _verifyPlayIntegrity(),
      _verifyDeviceIntegrity(),
    ]);

    _lastVerificationPassed = results.every((r) => r);
    _lastVerificationTime = DateTime.now();

    return _lastVerificationPassed;
  }

  /// Verify package name matches expected value
  Future<bool> _verifyPackageName() async {
    try {
      final packageName = await _getPackageName();
      final expected = SecurityConfig.expectedPackageName;

      if (packageName == expected) {
        debugPrint('[AntiClone] Package name verification passed: $packageName');
        return true;
      } else {
        debugPrint('[AntiClone] Package name mismatch! Expected: $expected, Got: $packageName');
        return false;
      }
    } catch (e) {
      debugPrint('[AntiClone] Package name verification error: $e');
      return false;
    }
  }

  /// Verify APK signature matches expected value
  Future<bool> _verifyApkSignature() async {
    try {
      final signature = await _getApkSignature();
      final expected = SecurityConfig.expectedApkSignatureSha256;

      // If no expected signature is configured, skip this check
      if (expected.isEmpty) {
        debugPrint('[AntiClone] Signature verification skipped (no expected signature configured)');
        return true;
      }

      if (signature == expected) {
        debugPrint('[AntiClone] Signature verification passed');
        return true;
      } else {
        debugPrint('[AntiClone] Signature mismatch! Expected: $expected, Got: $signature');
        return false;
      }
    } catch (e) {
      debugPrint('[AntiClone] Signature verification error: $e');
      return false;
    }
  }

  /// Verify Play Integrity token
  Future<bool> _verifyPlayIntegrity() async {
    try {
      if (!kReleaseMode) {
        debugPrint('[AntiClone] Play Integrity verification skipped in debug mode');
        return true;
      }

      final verdict = await PlayIntegrityService.instance.verifyWithBackend(
        SecurityConfig.integrityVerificationEndpoint,
      );

      if (verdict.isGenuine) {
        debugPrint('[AntiClone] Play Integrity verification passed');
        return true;
      } else {
        debugPrint('[AntiClone] Play Integrity verification failed: ${verdict.error}');
        return false;
      }
    } catch (e) {
      debugPrint('[AntiClone] Play Integrity verification error: $e');
      // Don't fail completely on Play Integrity errors (network issues, etc.)
      return true;
    }
  }

  /// Verify device integrity (root, emulator, etc.)
  Future<bool> _verifyDeviceIntegrity() async {
    try {
      final isRooted = await SecurityNative.isRooted();
      final isEmulator = await SecurityNative.isEmulator();
      final isDebuggable = await SecurityNative.isDebuggable();

      if (isRooted) {
        debugPrint('[AntiClone] Device is rooted - verification failed');
        return false;
      }

      if (isEmulator) {
        debugPrint('[AntiClone] Device is emulator - verification failed');
        return false;
      }

      if (isDebuggable) {
        debugPrint('[AntiClone] Device is debuggable - verification failed');
        return false;
      }

      debugPrint('[AntiClone] Device integrity verification passed');
      return true;
    } catch (e) {
      debugPrint('[AntiClone] Device integrity verification error: $e');
      return false;
    }
  }

  /// Get current package name from native layer
  Future<String> _getPackageName() async {
    try {
      return await _channel.invokeMethod<String>('getPackageName') ?? '';
    } catch (e) {
      debugPrint('[AntiClone] Failed to get package name: $e');
      return '';
    }
  }

  /// Get current APK signature from native layer
  Future<String> _getApkSignature() async {
    try {
      return await _channel.invokeMethod<String>('getApkSignatureSha256') ?? '';
    } catch (e) {
      debugPrint('[AntiClone] Failed to get APK signature: $e');
      return '';
    }
  }

  /// Get current package info for debugging
  Map<String, String> getPackageInfo() {
    return {
      'packageName': _currentPackageName ?? 'unknown',
      'signature': _currentSignature?.substring(0, 8) ?? 'unknown',
      'lastVerification': _lastVerificationTime?.toIso8601String() ?? 'never',
      'verificationPassed': _lastVerificationPassed.toString(),
    };
  }

  /// Force re-verification
  Future<bool> forceVerification() async {
    debugPrint('[AntiClone] Forcing re-verification...');
    return await verifyAll();
  }

  /// Get verification status
  bool get isVerified => _lastVerificationPassed;
  bool get isInitialized => _isInitialized;
  DateTime? get lastVerificationTime => _lastVerificationTime;
}
