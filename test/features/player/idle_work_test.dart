import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/core/player/idle_playback_gate.dart';

void main() {
  group('PlayerPlaybackIdleGate.shouldSkipBackgroundWork', () {
    test('probe is skipped when playing == true', () {
      expect(
        PlayerPlaybackIdleGate.shouldSkipBackgroundWork(
          isPlaying: true,
          isLowRam: false,
        ),
        isTrue,
      );
    });

    test('probe skipped on low RAM even when paused', () {
      expect(
        PlayerPlaybackIdleGate.shouldSkipBackgroundWork(
          isPlaying: false,
          isLowRam: true,
        ),
        isTrue,
      );
    });
  });

  group('PlayerPlaybackIdleGate.shouldRunIdleWorkAfterDelay', () {
    test('probe runs when paused for > 5 seconds', () async {
      var playing = false;
      final run = await PlayerPlaybackIdleGate.shouldRunIdleWorkAfterDelay(
        isPlayingNow: () async => playing,
        idleDelay: const Duration(milliseconds: 50),
      );
      expect(run, isTrue);
    });

    test('probe cancelled if playback resumes during wait', () async {
      var playing = false;
      final future = PlayerPlaybackIdleGate.shouldRunIdleWorkAfterDelay(
        isPlayingNow: () async => playing,
        idleDelay: const Duration(milliseconds: 80),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      playing = true;
      expect(await future, isFalse);
    });
  });
}
