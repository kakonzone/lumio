import 'agent_debug_log.dart';

/// Session-scoped NDJSON debug log (Cursor debug mode).
void sessionDebugLog({
  required String location,
  required String message,
  required String hypothesisId,
  Map<String, dynamic>? data,
  String runId = 'pre-fix',
}) {
  AgentDebugLog.log(
    location: location,
    message: message,
    hypothesisId: hypothesisId,
    data: data ?? const {},
    runId: runId,
  );
}
