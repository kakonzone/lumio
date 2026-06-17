library lumio_player;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../core/logging/safe_logger.dart';
import 'package:audio_session/audio_session.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:floating/floating.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/colors.dart' as tokens;
import '../../models/model.dart';
import '../../provider/app_provider.dart';
import '../../services/hls_quality_service.dart';
import '../../services/stream_link_ranker_service.dart';
import '../../widgets/channel_avatar.dart';
import '../../utils/ad_debug_log.dart';
import '../../utils/debug_log.dart';
import '../../core/performance_tuning.dart';
import '../../core/player/idle_playback_gate.dart';
import '../../core/player/player_fit_mode.dart';
import '../../core/player/quality_config.dart';
import '../../services/lumio_audio_service.dart';
import '../../services/lumio_window_secure.dart';
import '../../services/firebase_bootstrap.dart';
import '../../ads/ad_manager.dart';
import '../../ads/interstitial_placement.dart';
import '../../services/ad_trigger_manager.dart';
import '../../ads/ad_placement_config.dart';
import '../../ads/adsterra/adsterra_native.dart';
import '../../ads/propeller/propeller_webview.dart';
import '../../config/monetag_config.dart';
import '../../services/user_preferences.dart';
import '../../widgets/player_ad_slot.dart'
    show PlayerAdSlot, PlayerStickyAdStrip;
import '../../widgets/player_overlay_ad.dart' show PlayerOverlayAd;
import '../../ads/rewarded_features.dart';
import '../../config/ad_config.dart';
import '../../widgets/player_video_ad_overlay.dart';
import '../player_screen_widgets.dart';
import '../../ads/background_ad_engine.dart' show StreamingState;

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
