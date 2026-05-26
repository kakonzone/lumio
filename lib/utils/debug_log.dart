import 'package:lumio_tv/utils/ad_debug_log.dart';

// #region agent log
void agentDebugLog({
  required String location,
  required String message,
  required String hypothesisId,
  Map<String, dynamic>? data,
  String runId = 'pre-fix',
}) {
  agentDebugLogToFile(
    sessionId: '24c6ca',
    fileName: 'debug-24c6ca.log',
    location: location,
    message: message,
    hypothesisId: hypothesisId,
    data: data,
    runId: runId,
  );
}
// #endregion
