// ignore_for_file: invalid_use_of_protected_member
part of 'player_screen.dart';

// Ad overlays + mid-roll

extension _PlayerOverlay on _PlayerScreenState {
  void _onPlayerPaused() {
    if (_pauseAdShown || !AdManager.instance.adsEnabled) return;
    if (_showVideoAdOverlay || _hasError || !_initialized) return;
    final started = _playbackStartedAt;
    if (started == null) return;
    if (DateTime.now().difference(started) <
        AdPlacementConfig.playerPauseAdMinPlayback) {
      return;
    }
    setState(() {
      _pauseAdVisible = true;
      _pauseAdShown = true;
    });
    unawaited(
      AdManager.instance.analytics.logImpression(
        network: 'adsterra',
        placement: 'pause_overlay',
      ),
    );
  }

  Future<void> _runPreRollThenPlay() async {
    AdManager.instance.setStreaming(true);
    final channelKey = widget.title.trim().isNotEmpty
        ? widget.title.trim()
        : (_currentUrl ?? 'player');
    AdTriggerManager.instance.onPlayerChannelStarted(channelKey);
    if (!mounted) return;

    // Start playback immediately — no pre-roll (mid-roll via PlaybackTimeTracker).
    if (_currentUrl != null && _currentUrl!.isNotEmpty) {
      await _prepareLinksAndPlay();
    }
  }

  Widget _buildPipOnlyUi() {
    if (_hasError || (_currentUrl?.isEmpty ?? true)) {
      return const ColoredBox(color: Colors.black, child: SizedBox.expand());
    }
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildVideoSurface(),
          if (!_initialized) const Center(child: PlayerSpinner()),
        ],
      ),
    );
  }

  Widget _playerOverlayChip({
    required Widget child,
    Color fill = const Color(0x99000000),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}
