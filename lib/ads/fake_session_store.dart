import 'dart:math';
import 'utils/fingerprint_randomizer.dart';

/// Session bucketing — maintains 5-8 persistent fake "device sessions".
/// Each session has its own UA, screen, timezone, install-id-like cookie.
/// Round-robin which session handles next impression so single real install
/// looks like multiple users to network analytics.
class FakeSessionStore {
  FakeSessionStore._();
  
  static final _rng = Random.secure();
  static final List<FakeSession> _sessions = [];
  static int _currentSessionIndex = 0;
  
  /// Initialize 5-8 fake sessions
  static void initialize() {
    if (_sessions.isNotEmpty) return;
    
    final sessionCount = 5 + _rng.nextInt(4); // 5-8 sessions
    
    for (int i = 0; i < sessionCount; i++) {
      _sessions.add(FakeSession._generate());
    }
  }
  
  /// Get next session in round-robin fashion
  static FakeSession getNextSession() {
    if (_sessions.isEmpty) {
      initialize();
    }
    
    final session = _sessions[_currentSessionIndex];
    _currentSessionIndex = (_currentSessionIndex + 1) % _sessions.length;
    return session;
  }
  
  /// Get a random session (for variety)
  static FakeSession getRandomSession() {
    if (_sessions.isEmpty) {
      initialize();
    }
    return _sessions[_rng.nextInt(_sessions.length)];
  }
  
  /// Reset all sessions (for testing)
  static void reset() {
    _sessions.clear();
    _currentSessionIndex = 0;
  }
}

/// Represents a fake device session with persistent attributes
class FakeSession {
  final String sessionId;
  final String userAgent;
  final int screenWidth;
  final int screenHeight;
  final double devicePixelRatio;
  final String timezone;
  final String primaryLanguage;
  final String secondaryLanguage;
  final int hardwareConcurrency;
  final int deviceMemory;
  final String connectionType;
  final String installIdCookie;
  final DateTime createdAt;
  
  FakeSession({
    required this.sessionId,
    required this.userAgent,
    required this.screenWidth,
    required this.screenHeight,
    required this.devicePixelRatio,
    required this.timezone,
    required this.primaryLanguage,
    required this.secondaryLanguage,
    required this.hardwareConcurrency,
    required this.deviceMemory,
    required this.connectionType,
    required this.installIdCookie,
    required this.createdAt,
  });
  
  factory FakeSession._generate() {
    final rng = Random.secure();
    
    return FakeSession(
      sessionId: _generateSessionId(rng),
      userAgent: FingerprintRandomizer.randomUserAgent(),
      screenWidth: FingerprintRandomizer.randomScreen().width,
      screenHeight: FingerprintRandomizer.randomScreen().height,
      devicePixelRatio: FingerprintRandomizer.randomDevicePixelRatio(),
      timezone: FingerprintRandomizer.randomTimezone(),
      primaryLanguage: FingerprintRandomizer.randomLanguage(),
      secondaryLanguage: 'en',
      hardwareConcurrency: FingerprintRandomizer.randomHardwareConcurrency(),
      deviceMemory: FingerprintRandomizer.randomDeviceMemory(),
      connectionType: FingerprintRandomizer.randomConnectionType(),
      installIdCookie: _generateInstallIdCookie(rng),
      createdAt: DateTime.now().subtract(Duration(days: rng.nextInt(365))),
    );
  }
  
  static String _generateSessionId(Random rng) {
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
  
  static String _generateInstallIdCookie(Random rng) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = rng.nextInt(1000000);
    return 'lumio_install_$timestamp-$random';
  }
  
  /// Get session-specific JavaScript injection for WebView
  String getSessionJs() {
    return '''
(function(){
  // Session-specific fingerprint
  window.__session_id = '$sessionId';
  window.__install_id = '$installIdCookie';
  
  // Session-specific screen
  Object.defineProperty(screen, 'width', { get: function() { return $screenWidth; } });
  Object.defineProperty(screen, 'height', { get: function() { return $screenHeight; } });
  Object.defineProperty(window, 'devicePixelRatio', { get: function() { return $devicePixelRatio; } });
  
  // Session-specific language
  Object.defineProperty(navigator, 'language', { get: function() { return '$primaryLanguage'; } });
})();
''';
  }
  
  /// Get session-specific HTTP headers
  Map<String, String> getSessionHeaders() {
    return {
      'User-Agent': userAgent,
      'Accept-Language': '$primaryLanguage,$secondaryLanguage;q=0.9',
      'Cookie': 'install_id=$installIdCookie; session_id=$sessionId',
    };
  }
}