import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Application logger that respects build mode.
/// 
/// In debug mode: logs to console with detailed output
/// In release mode: completely silent for performance
class AppLogger {
  AppLogger._();

  static final Logger _root = Logger('Lumio');
  static bool _initialized = false;

  /// Initialize the logger with appropriate level for build mode.
  static void initialize() {
    if (_initialized) return;
    
    Logger.root.level = kDebugMode ? Level.ALL : Level.OFF;
    
    if (kDebugMode) {
      Logger.root.onRecord.listen((record) {
        final emoji = _getEmoji(record.level);
        final message = '$emoji ${record.level.name}: ${record.message}';
        
        if (record.error != null) {
          debugPrint('$message\n${record.error}');
          if (record.stackTrace != null) {
            debugPrint(record.stackTrace.toString());
          }
        } else {
          debugPrint(message);
        }
      });
    }
    
    _initialized = true;
  }

  static String _getEmoji(Level level) {
    if (level.value < Level.CONFIG.value) return '🔍';
    if (level.value < Level.INFO.value) return '⚙️';
    if (level.value < Level.WARNING.value) return 'ℹ️';
    if (level.value < Level.SEVERE.value) return '⚠️';
    return '�';
  }

  /// Get a logger for a specific subsystem.
  static Logger getLogger(String name) {
    if (!_initialized) {
      initialize();
    }
    return Logger(name);
  }

  /// Convenience method for logging at info level.
  static void info(String message, {String? subsystem}) {
    final logger = subsystem != null ? getLogger(subsystem) : _root;
    logger.info(message);
  }

  /// Convenience method for logging at warning level.
  static void warning(String message, {String? subsystem}) {
    final logger = subsystem != null ? getLogger(subsystem) : _root;
    logger.warning(message);
  }

  /// Convenience method for logging at severe level.
  static void severe(String message, {String? subsystem, Object? error, StackTrace? stackTrace}) {
    final logger = subsystem != null ? getLogger(subsystem) : _root;
    logger.severe(message, error, stackTrace);
  }

  /// Convenience method for logging at fine level (debug details).
  static void fine(String message, {String? subsystem}) {
    final logger = subsystem != null ? getLogger(subsystem) : _root;
    logger.fine(message);
  }
}

/// Extension to add convenience methods to Logger.
extension AppLoggerExtension on Logger {
  void logInfo(String message) => info(message);
  void logWarning(String message) => warning(message);
  void logSevere(String message, [Object? error, StackTrace? stackTrace]) => 
      severe(message, error, stackTrace);
  void logFine(String message) => fine(message);
}
