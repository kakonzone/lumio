import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:media_kit/media_kit.dart';

/// Bridges [media_kit] [Player] to system background playback / media controls.
class LumioAudioHandler extends BaseAudioHandler with SeekHandler {
  Player? _player;
  final List<StreamSubscription<dynamic>> _subs = [];

  bool get hasPlayer => _player != null;

  void attachPlayer(Player player) {
    if (identical(_player, player)) return;
    detachPlayer(silent: true);
    _player = player;
    _subs.add(player.stream.playing.listen((_) => _broadcastState()));
    _subs.add(player.stream.position.listen((_) => _broadcastState()));
    _subs.add(player.stream.buffer.listen((_) => _broadcastState()));
    _subs.add(player.stream.buffering.listen((_) => _broadcastState()));
    _subs.add(player.stream.duration.listen((duration) {
      final item = mediaItem.value;
      if (item != null && duration > Duration.zero) {
        mediaItem.add(item.copyWith(duration: duration));
      }
    }));
    _broadcastState();
  }

  void detachPlayer({bool silent = false}) {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
    _player = null;
    if (!silent) {
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.idle,
          playing: false,
        ),
      );
    }
  }

  void setNowPlaying({
    required String title,
    String artist = 'Lumio',
    String? mediaId,
    Uri? artUri,
  }) {
    mediaItem.add(
      MediaItem(
        id: mediaId ?? title,
        title: title,
        artist: artist,
        artUri: artUri,
      ),
    );
    _broadcastState();
  }

  void _broadcastState() {
    final player = _player;
    if (player == null) return;
    final s = player.state;
    final playing = s.playing;
    playbackState.add(
      PlaybackState(
        controls: [
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
        ],
        androidCompactActionIndices: const [0],
        systemActions: const {MediaAction.seek, MediaAction.stop},
        processingState: s.buffering
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        playing: playing,
        updatePosition: s.position,
        bufferedPosition: s.buffer,
        speed: s.rate,
      ),
    );
  }

  @override
  Future<void> play() async {
    await _player?.play();
  }

  @override
  Future<void> pause() async {
    await _player?.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player?.seek(position);
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
    await super.stop();
  }
}

LumioAudioHandler? _cachedHandler;

Future<LumioAudioHandler> ensureLumioAudioService() async {
  if (_cachedHandler != null) return _cachedHandler!;
  _cachedHandler = await AudioService.init(
    builder: () => LumioAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.kakonzone.lumio.playback',
      androidNotificationChannelName: 'Lumio Playback',
      androidStopForegroundOnPause: false,
    ),
  );
  try {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.movie,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ),
    );
  } catch (_) {}
  return _cachedHandler!;
}

LumioAudioHandler? get lumioAudioHandlerOrNull => _cachedHandler;
