part of 'player_screen.dart';

// #region agent log
void _debugSessionLog({
  required String location,
  required String message,
  required String hypothesisId,
  Map<String, dynamic>? data,
  String runId = 'verify',
}) {
  if (!kDebugMode) return;
  agentDebugLogToFile(
    sessionId: '6f9d36',
    fileName: 'debug-6f9d36.log',
    location: location,
    message: message,
    hypothesisId: hypothesisId,
    data: data,
    runId: runId,
  );
}
// #endregion
