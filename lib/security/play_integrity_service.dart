import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Play Integrity API verification service
///
/// Verifies app integrity using Google Play Integrity API
/// Backend validates the token and checks for:
/// - MEETS_DEVICE_INTEGRITY
/// - MEETS_BASIC_INTEGRITY
/// - PLAY_RECOGNIZED
class PlayIntegrityService {
  PlayIntegrityService._();
  static final PlayIntegrityService instance = PlayIntegrityService._();

  static const _channel = MethodChannel('com.lumio.security/native');
  
  // Cloud project number from Google Cloud Console
  static const _cloudProjectNumber = 123456789; // Replace with your actual project number

  String? _cachedToken;
  DateTime? _tokenExpiry;
  static const _tokenTtl = Duration(minutes: 10);

  /// Initialize the Play Integrity API
  Future<bool> initialize() async {
    try {
      if (!kReleaseMode) {
        debugPrint('[PlayIntegrity] Skipping initialization in debug mode');
        return true;
      }

      await _channel.invokeMethod('initializePlayIntegrity');
      debugPrint('[PlayIntegrity] Initialized successfully');
      return true;
    } catch (e) {
      debugPrint('[PlayIntegrity] Initialization failed: $e');
      return false;
    }
  }

  /// Request integrity token from Play Integrity API
  Future<String?> requestIntegrityToken() async {
    if (!kReleaseMode) {
      debugPrint('[PlayIntegrity] Skipping token request in debug mode');
      return 'debug_token';
    }

    // Check if cached token is still valid
    if (_cachedToken != null && 
        _tokenExpiry != null && 
        DateTime.now().isBefore(_tokenExpiry!)) {
      debugPrint('[PlayIntegrity] Using cached token');
      return _cachedToken;
    }

    try {
      final result = await _channel.invokeMethod<String>(
        'requestIntegrityToken',
        {'cloudProjectNumber': _cloudProjectNumber},
      );

      if (result != null) {
        _cachedToken = result;
        _tokenExpiry = DateTime.now().add(_tokenTtl);
        debugPrint('[PlayIntegrity] Token received successfully');
        return result;
      }

      debugPrint('[PlayIntegrity] Token request returned null');
      return null;
    } catch (e) {
      debugPrint('[PlayIntegrity] Token request failed: $e');
      return null;
    }
  }

  /// Verify integrity with backend
  ///
  /// Sends the integrity token to backend for validation
  /// Backend should check the token verdict includes:
  /// - MEETS_DEVICE_INTEGRITY
  /// - MEETS_BASIC_INTEGRITY  
  /// - PLAY_RECOGNIZED
  Future<IntegrityVerdict> verifyWithBackend(String backendUrl) async {
    final token = await requestIntegrityToken();
    if (token == null) {
      return IntegrityVerdict(
        isGenuine: false,
        error: 'Failed to obtain integrity token',
      );
    }

    try {
      // In production, make actual HTTP request to backend
      // For now, return a mock response
      debugPrint('[PlayIntegrity] Would send token to backend: $backendUrl');
      
      // TODO: Implement actual HTTP request
      // final response = await http.post(
      //   Uri.parse('$backendUrl/verify-integrity'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode({'integrityToken': token}),
      // );

      return IntegrityVerdict(
        isGenuine: true,
        meetsDeviceIntegrity: true,
        meetsBasicIntegrity: true,
        playRecognized: true,
      );
    } catch (e) {
      debugPrint('[PlayIntegrity] Backend verification failed: $e');
      return IntegrityVerdict(
        isGenuine: false,
        error: 'Backend verification failed: $e',
      );
    }
  }

  /// Clear cached token
  void clearCache() {
    _cachedToken = null;
    _tokenExpiry = null;
  }

  /// Check if cached token is valid
  bool isCacheValid() {
    return _cachedToken != null &&
           _tokenExpiry != null &&
           DateTime.now().isBefore(_tokenExpiry!);
  }
}

/// Result of integrity verification
class IntegrityVerdict {
  final bool isGenuine;
  final bool? meetsDeviceIntegrity;
  final bool? meetsBasicIntegrity;
  final bool? playRecognized;
  final String? error;

  IntegrityVerdict({
    required this.isGenuine,
    this.meetsDeviceIntegrity,
    this.meetsBasicIntegrity,
    this.playRecognized,
    this.error,
  });

  @override
  String toString() {
    return 'IntegrityVerdict{isGenuine: $isGenuine, '
           'meetsDeviceIntegrity: $meetsDeviceIntegrity, '
           'meetsBasicIntegrity: $meetsBasicIntegrity, '
           'playRecognized: $playRecognized, '
           'error: $error}';
  }
}
