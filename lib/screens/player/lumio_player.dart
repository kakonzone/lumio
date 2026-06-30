library;

import 'package:flutter/foundation.dart' show kDebugMode;
import '../../utils/ad_debug_log.dart';

part 'player_screen.dart';
part 'player_state_manager.dart';
part 'player_failover.dart';
part 'player_controls_bar.dart';
part 'player_overlay.dart';

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
