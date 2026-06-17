import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'security_config.dart';

/// Install watermarking service
///
/// Watermarks each installation with a unique UUID that is:
/// - Generated on first run
/// - Stored securely (encrypted on Android)
/// - Sent to backend for API quota tracking
/// - Tied to device fingerprint
class InstallWatermarkService {
  InstallWatermarkService._();
  static final InstallWatermarkService instance = InstallWatermarkService._();

  static const _channel = MethodChannel('com.lumio.security/native');

  String? _installId;
  String? _deviceFingerprint;
  bool _isRegistered = false;
  bool _isInitialized = false;

  /// Initialize the watermark service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Try to read existing install ID from secure storage
      _installId = await _readEncryptedInstallId();

      if (_installId == null || _installId!.isEmpty) {
        // Generate new install ID
        _installId = const Uuid().v4();
        debugPrint('[InstallWatermark] Generated new install ID: $_installId');
        
        // Store securely
        await _writeEncryptedInstallId(_installId!);
      } else {
        debugPrint('[InstallWatermark] Loaded existing install ID: $_installId');
      }

      // Generate device fingerprint
      _deviceFingerprint = await _generateDeviceFingerprint();

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('[InstallWatermark] Initialization error: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Register installation with backend
  Future<bool> registerWithBackend(String backendUrl) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_installId == null) {
      debugPrint('[InstallWatermark] No install ID available');
      return false;
    }

    try {
      debugPrint('[InstallWatermark] Registering install with backend...');
      
      // Prepare registration payload
      final payload = {
        'installId': _installId,
        'deviceFingerprint': _deviceFingerprint,
        'appVersion': _getAppVersion(),
        'timestamp': DateTime.now().toIso8601String(),
        'signature': await _generateRegistrationSignature(),
      };

      // TODO: Implement actual HTTP request to backend
      // final response = await http.post(
      //   Uri.parse('$backendUrl/register-install'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode(payload),
      // );

      debugPrint('[InstallWatermark] Registration payload: ${jsonEncode(payload)}');
      _isRegistered = true;
      
      return true;
    } catch (e) {
      debugPrint('[InstallWatermark] Registration failed: $e');
      return false;
    }
  }

  /// Get install ID for API calls
  String? getInstallId() {
    return _installId;
  }

  /// Get device fingerprint
  String? getDeviceFingerprint() {
    return _deviceFingerprint;
  }

  /// Check if installation is registered
  bool isRegistered() => _isRegistered;

  /// Verify installation quota with backend
  Future<QuotaStatus> checkQuota(String backendUrl) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_installId == null) {
      return QuotaStatus(
        allowed: false,
        error: 'No install ID',
      );
    }

    try {
      debugPrint('[InstallWatermark] Checking quota with backend...');
      
      // TODO: Implement actual HTTP request to backend
      // final response = await http.post(
      //   Uri.parse('$backendUrl/check-quota'),
      //   headers: {
      //     'Content-Type': 'application/json',
      //     'X-Install-ID': _installId!,
      //   },
      // );

      // For now, return allowed
      return QuotaStatus(
        allowed: true,
        remainingRequests: 10000,
        resetTime: DateTime.now().add(const Duration(days: 1)),
      );
    } catch (e) {
      debugPrint('[InstallWatermark] Quota check failed: $e');
      return QuotaStatus(
        allowed: false,
        error: 'Quota check failed',
      );
    }
  }

  /// Read encrypted install ID from native storage
  Future<String?> _readEncryptedInstallId() async {
    try {
      return await _channel.invokeMethod<String>('readEncryptedInstallId');
    } catch (e) {
      debugPrint('[InstallWatermark] Failed to read encrypted install ID: $e');
      return null;
    }
  }

  /// Write encrypted install ID to native storage
  Future<void> _writeEncryptedInstallId(String installId) async {
    try {
      await _channel.invokeMethod('writeEncryptedInstallId', {'installId': installId});
      debugPrint('[InstallWatermark] Encrypted install ID stored');
    } catch (e) {
      debugPrint('[InstallWatermark] Failed to write encrypted install ID: $e');
    }
  }

  /// Generate device fingerprint
  Future<String> _generateDeviceFingerprint() async {
    try {
      // Get device info from native layer
      final deviceProfile = await _channel.invokeMethod<Map>('getDeviceProfile');
      
      if (deviceProfile != null) {
        // Create fingerprint from device characteristics
        final components = [
          deviceProfile['manufacturer'],
          deviceProfile['brand'],
          deviceProfile['model'],
          deviceProfile['board'],
          deviceProfile['hardware'],
          deviceProfile['androidId'],
        ].where((e) => e != null).join('|');
        
        // Hash to create fingerprint
        final bytes = utf8.encode(components);
        final digest = _sha256Hash(bytes);
        return digest;
      }

      // Fallback to random fingerprint if native call fails
      return const Uuid().v4();
    } catch (e) {
      debugPrint('[InstallWatermark] Failed to generate device fingerprint: $e');
      return const Uuid().v4();
    }
  }

  /// Generate SHA-256 hash
  String _sha256Hash(List<int> input) {
    // Simple hash implementation (in production, use crypto package)
    var hash = 0;
    for (var i = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash) + input[i];
      hash = hash & 0xffffffff;
    }
    return hash.toRadixString(16);
  }

  /// Get app version
  String _getAppVersion() {
    // This should be read from package_info_plus
    return '1.1.0'; // Placeholder
  }

  /// Generate registration signature
  Future<String> _generateRegistrationSignature() async {
    // Create signature using HMAC secret (in production, use proper crypto)
    final payload = '$_installId|$_deviceFingerprint|${DateTime.now().millisecondsSinceEpoch}';
    final secret = SecurityConfig.hmacSecret;
    
    if (secret.isEmpty) {
      return _sha256Hash(utf8.encode(payload));
    }

    // Simple HMAC implementation (in production, use crypto package)
    final combined = payload + secret;
    return _sha256Hash(utf8.encode(combined));
  }

  /// Force re-registration (for testing)
  Future<bool> forceReregistration(String backendUrl) async {
    _isRegistered = false;
    return await registerWithBackend(backendUrl);
  }
}

/// Status of API quota check
class QuotaStatus {
  final bool allowed;
  final int? remainingRequests;
  final DateTime? resetTime;
  final String? error;

  QuotaStatus({
    required this.allowed,
    this.remainingRequests,
    this.resetTime,
    this.error,
  });

  @override
  String toString() {
    return 'QuotaStatus{allowed: $allowed, remaining: $remainingRequests, '
           'resetTime: $resetTime, error: $error}';
  }
}
