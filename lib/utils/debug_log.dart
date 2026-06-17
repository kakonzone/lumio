import 'package:lumio_tv/utils/ad_debug_log.dart';
import 'package:lumio_tv/core/logging/safe_logger.dart';

// #region agent log
void agentDebugLog({
  required String location,
  required String message,
  required String hypothesisId,
  Map<String, dynamic>? data,
  String runId = 'pre-fix',
}) {
  SafeLogger.debug('agent', '$location: $message ($hypothesisId) $data');
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
