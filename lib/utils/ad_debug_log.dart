import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../ads/adsterra_telemetry_client.dart';
import '../services/ad_safety_service.dart';

/// Adsterra / aggressive-layer telemetry (debug log + optional release POST).
void logAdsterraTelemetry({
  required String placement,
  required String format,
  Map<String, dynamic>? extra,
}) {
  if (!kReleaseMode) {
    debugPrint(
      '[AdsterraTelemetry] $format placement=$placement '
      'fp=${AdSafetyService.instance.deviceFingerprint} extra=$extra',
    );
  }
  AdsterraTelemetryService.instance.report(
    placement: placement,
    format: format,
    extra: extra,
  );
}

/// Structured ads-layer logging (errors always tagged for logcat grep).
class AdDebugLog {
  AdDebugLog._();

  static void error(
    String location,
    String message, {
    Map<String, dynamic>? data,
  }) {
    final extra = data == null ? '' : ' data=$data';
    debugPrint('[AdDebug] ERROR $location: $message$extra');
    _appendFile('level=ERROR location=$location message=$message$extra');
  }

  static void info(String location, String message) {
    debugPrint('[AdDebug] $location: $message');
    if (!kReleaseMode) {
      _appendFile('location=$location message=$message');
    }
  }

  static Future<void> _appendFile(String line) async {
    if (kReleaseMode) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/lumio_ad_debug.log');
      await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('[AdDebug] file write skipped: $e');
    }
  }
}

/// Portable NDJSON agent log (no hardcoded host paths).
Future<void> agentDebugLogToFile({
  required String sessionId,
  required String fileName,
  required String location,
  required String message,
  required String hypothesisId,
  Map<String, dynamic>? data,
  String runId = 'verify',
}) async {
  if (kReleaseMode) return;
  final payload = <String, dynamic>{
    'sessionId': sessionId,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'location': location,
    'message': message,
    'hypothesisId': hypothesisId,
    'runId': runId,
    if (data != null) 'data': data,
  };
  debugPrint('[agent] $location: $message');
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(
      '${jsonEncode(payload)}\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (e) {
    debugPrint('[agent] file write skipped: $e');
  }
}

/// No-op outside ads layer — kept for legacy call sites outside `lib/ads/`.
void adDebugLog({
  required String location,
  required String message,
  required String hypothesisId,
  Map<String, dynamic>? data,
}) {
  if (!kReleaseMode) {
    debugPrint('[adDebug] $location: $message ($hypothesisId) $data');
  }
}
