part of lumio_player;

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
    
    // Show in-player video ad overlay (Adsterra WebView) for preroll
    if (AdManager.instance.adsEnabled) {
      setState(() => _showVideoAdOverlay = true);
      _videoAdCompleter = Completer<void>();
      
      // Wait for ad to be dismissed
      await _videoAdCompleter?.future;
      
      if (!mounted) return;
      setState(() => _showVideoAdOverlay = false);
    }
    
    if (!mounted) return;
    if (_currentUrl != null && _currentUrl!.isNotEmpty) {
      await _prepareLinksAndPlay();
    }
    if (!mounted) return;
    _startMidRollTimer();
  }

  Future<void> _presentMidRollInterstitial() async {
    if (!mounted) return;
    try {
      await _player.pause();
    } catch (_) {}
    if (!mounted) return;

    // Show in-player video ad overlay (Adsterra WebView) for midroll
    setState(() => _showVideoAdOverlay = true);
    _videoAdCompleter = Completer<void>();
    
    // Wait for ad to be dismissed
    await _videoAdCompleter?.future;

    if (!mounted) return;
    setState(() => _showVideoAdOverlay = false);

    if (_initialized && !_hasError) {
      try {
        await _player.play();
      } catch (e) {
        debugPrint('[MidRoll] resume play failed: $e');
      }
    }
  }

  void _startMidRollTimer() {
    _midRollTimer?.cancel();
    if (!AdManager.instance.adsEnabled) return;
    
    // Schedule mid-roll ads at 20min and 50min
    final now = DateTime.now();
    final ad20Min = now.add(const Duration(minutes: 20));
    final ad50Min = now.add(const Duration(minutes: 50));
    
    _midRollTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _hasError || !_initialized) {
        return;
      }
      
      final elapsed = DateTime.now().difference(now);
      
      // Show ad at 20min
      if (elapsed >= const Duration(minutes: 20) && elapsed < const Duration(minutes: 21)) {
        if (!_midRoll20Shown) {
          _midRoll20Shown = true;
          unawaited(_presentMidRollInterstitial());
        }
      }
      
      // Show ad at 50min
      if (elapsed >= const Duration(minutes: 50) && elapsed < const Duration(minutes: 51)) {
        if (!_midRoll50Shown) {
          _midRoll50Shown = true;
          unawaited(_presentMidRollInterstitial());
        }
      }
    });
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
