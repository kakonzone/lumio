import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Session debug logger — NDJSON to ingest server, host log file, and device temp dir.
class AgentDebugLog {
  AgentDebugLog._();

  static const _sessionId = '290c83';
  static const _endpoint =
      'http://127.0.0.1:7374/ingest/60c5be44-ad06-4b3d-b19e-40e8d15a5747';
  static const _hostLogPath =
      '/home/kakonzone/Downloads/FlutterProject/lumio/.cursor/debug-290c83.log';

  static String? _mobileLogPath;
  static bool _initStarted = false;

  /// Call once from main() after [WidgetsFlutterBinding.ensureInitialized].
  static Future<void> init() async {
    if (_initStarted) return;
    _initStarted = true;
    if (kIsWeb) return;
    try {
      final dir = await getTemporaryDirectory();
      _mobileLogPath = '${dir.path}/debug-290c83.log';
    } catch (_) {}
  }

  static void log({
    required String location,
    required String message,
    required String hypothesisId,
    Map<String, Object?> data = const {},
    String runId = 'pre-fix',
  }) {
    final payload = <String, Object?>{
      'sessionId': _sessionId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'location': location,
      'message': message,
      'hypothesisId': hypothesisId,
      'runId': runId,
      'data': data,
    };
    final line = jsonEncode(payload);
    // Logcat-visible fallback for release APK on device.
    // ignore: avoid_print
    print('[AgentDebugLog] $line');
    unawaited(_post(line));
    unawaited(_appendHost(line));
    unawaited(_appendMobile(line));
  }

  static Future<void> _post(String line) async {
    try {
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse(_endpoint));
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('X-Debug-Session-Id', _sessionId);
      req.write(line);
      await req.close();
      client.close(force: true);
    } catch (_) {}
  }

  static Future<void> _appendHost(String line) async {
    try {
      await File(_hostLogPath).writeAsString('$line\n', mode: FileMode.append);
    } catch (_) {}
  }

  static Future<void> _appendMobile(String line) async {
    final path = _mobileLogPath;
    if (path == null) return;
    try {
      await File(path).writeAsString('$line\n', mode: FileMode.append);
    } catch (_) {}
  }
}
