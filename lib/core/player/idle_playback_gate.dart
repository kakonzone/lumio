/// Gates background player work (probe, mpv prewarm) away from active playback.
class PlayerPlaybackIdleGate {
  PlayerPlaybackIdleGate._();

  static bool shouldSkipBackgroundWork({
    required bool isPlaying,
    required bool isLowRam,
  }) {
    if (isPlaying) return true;
    if (isLowRam) return true;
    return false;
  }

  /// After [idleDelay] from pause, returns true only if still not playing.
  static Future<bool> shouldRunIdleWorkAfterDelay({
    required Future<bool> Function() isPlayingNow,
    Duration idleDelay = const Duration(seconds: 5),
  }) async {
    await Future.delayed(idleDelay);
    return !(await isPlayingNow());
  }
}
