import 'dart:convert';
import 'dart:io';

// #region agent log
void agentDebugLog({
  required String location,
  required String message,
  required String hypothesisId,
  Map<String, dynamic>? data,
  String runId = 'pre-fix',
}) {
  const path =
      '/home/kakonzone/Downloads/FlutterProject/lumio/.cursor/debug-24c6ca.log';
  try {
    final payload = <String, dynamic>{
      'sessionId': '24c6ca',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'location': location,
      'message': message,
      'hypothesisId': hypothesisId,
      'runId': runId,
      if (data != null) 'data': data,
    };
    File(path).writeAsStringSync('${jsonEncode(payload)}\n',
        mode: FileMode.append, flush: true);
  } catch (_) {}
}
// #endregion
