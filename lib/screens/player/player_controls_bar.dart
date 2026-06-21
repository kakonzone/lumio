part of lumio_player;

// Controls UI

extension _PlayerControls on _PlayerScreenState {
  Future<void> _loadFitMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode =
          parsePlayerFitMode(prefs.getString(_PlayerScreenState._fitPrefKey));
      if (mode != null && mounted) {
        setState(() => _fitMode = normalizePlayerFitModeForTap(mode));
      }
    } catch (_) {}
  }

  Future<void> _persistFitMode(PlayerFitMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_PlayerScreenState._fitPrefKey, mode.name);
    } catch (_) {}
  }

  void _setFitMode(PlayerFitMode mode) {
    if (!mounted) return;
    setState(() => _fitMode = mode);
    unawaited(_persistFitMode(mode));
    _revealControls();
  }

  void _cycleFitMode() {
    final next = nextPlayerFitModeInTapCycle(
      normalizePlayerFitModeForTap(_fitMode),
    );
    _setFitMode(next);
  }

  Widget _buildVideoSurface() {
    final fit = boxFitFor(_fitMode);
    final ratio = aspectRatioFor(_fitMode);
    final w = _player.state.width?.toDouble();
    final h = _player.state.height?.toDouble();
    final frameW = (w != null && w > 0) ? w : 1920.0;
    final frameH = (h != null && h > 0) ? h : 1080.0;

    Widget video = RepaintBoundary(
      child: Video(
        key: const ValueKey('lumio-player-video'),
        controller: _videoCtrl,
        controls: NoVideoControls,
        fit: fit,
        fill: Colors.black,
      ),
    );
    if (ratio != null) {
      video = AspectRatio(aspectRatio: ratio, child: video);
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: fit,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: frameW,
          height: frameH,
          child: video,
        ),
      ),
    );
  }

  void _updateQualityBadge() {
    if (!mounted) return;
    final w = _player.state.width ?? 0;
    final h = _player.state.height ?? 0;
    if (h > 0) _sourceHeight = h;
    String badge;
    if (_selectedTargetHeight == 0) {
      badge = h > 0 ? 'AUTO • ${_formatHeightLabel(h)}' : 'AUTO';
    } else {
      badge = h > 0 ? _formatHeightLabel(h) : '${_selectedTargetHeight}p';
    }
    if (badge != _qualityBadge) {
      if (!mounted) return;
      setState(() => _qualityBadge = badge);
      SafeLogger.debug('player',
          'player_screen.dart:_updateQualityBadge: quality badge updated (H-quality-badge) badge=$badge w=$w h=$h');
    }
  }

  String _formatHeightLabel(int h) {
    if (h >= 1080) return '1080p';
    if (h >= 720) return '720p';
    if (h >= 540) return '540p';
    if (h >= 480) return '480p';
    if (h >= 360) return '360p';
    if (h >= 270) return '270p';
    if (h >= 180) return '180p';
    return '${h}p';
  }

  double _safeUnitProgress(double value) {
    try {
      return value.clamp(0.0, 1.0);
    } catch (e, st) {
      SafeLogger.error('player',
          'player_screen.dart:_safeUnitProgress: Slider/Progress error', e, st);
      return 0.0;
    }
  }

  void _toggleControls() {
    if (!mounted) return;
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _revealControls({bool restartTimer = true}) {
    if (!mounted) return;
    if (!_showControls) setState(() => _showControls = true);
    if (restartTimer) _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _togglePlay() {
    final wasPlaying = _player.state.playing;
    _player.playOrPause();
    if (wasPlaying) {
      _revealControls();
    } else {
      _startHideTimer();
    }
  }

  IconData _fitModeIcon() {
    switch (_fitMode) {
      case PlayerFitMode.fit:
        return Icons.fit_screen_rounded;
      case PlayerFitMode.fill:
        return Icons.crop_free_rounded;
      case PlayerFitMode.stretch:
        return Icons.open_in_full_rounded;
      case PlayerFitMode.original:
        return Icons.photo_size_select_actual_rounded;
      case PlayerFitMode.ratio16_9:
      case PlayerFitMode.ratio4_3:
        return Icons.aspect_ratio_rounded;
    }
  }

  void _seek(int seconds) {
    final pos = _player.state.position + Duration(seconds: seconds);
    _player.seek(pos);
    _startHideTimer();
  }

  void _toggleFullscreen() {
    if (!mounted) return;
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      _exitFullscreen();
    }
  }

  void _exitFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    if (mounted) setState(() => _isFullscreen = false);
  }

  void _onDoubleTapDown(TapDownDetails d) {
    final w = MediaQuery.of(context).size.width;
    final rewind = d.localPosition.dx < w / 2;
    _seek(rewind ? -10 : 10);
    _showSeekOverlay(rewind ? '⏪ 10s' : '10s ⏩', rewind);
  }

  void _showSeekOverlay(String label, bool leftSide) {
    if (!mounted) return;
    setState(() {
      _seekOverlayLabel = label;
      _seekOverlayOpacity = 1.0;
    });
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
    });
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(milliseconds: 370), () {
      if (!mounted) return;
      setState(() => _seekOverlayOpacity = 0.0);
    });
    Timer(const Duration(milliseconds: 570), () {
      if (mounted) setState(() => _seekOverlayLabel = null);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    final vx = d.velocity.pixelsPerSecond.dx;
    if (vx.abs() <= 800) return;
    final now = DateTime.now();
    if (_lastSwipeAt != null &&
        now.difference(_lastSwipeAt!) < const Duration(milliseconds: 600)) {
      return;
    }
    _lastSwipeAt = now;
    final channels = _relatedDisplay;
    if (channels.isEmpty) return;
    var idx = channels.indexWhere(
      (c) =>
          c.name == _currentTitle ||
          (c.streamUrl.isNotEmpty && c.matchesStreamUrl(_currentUrl ?? '')),
    );
    if (idx < 0) idx = 0;
    final nextIdx = vx > 0
        ? (idx - 1 + channels.length) % channels.length
        : (idx + 1) % channels.length;
    final next = channels[nextIdx];
    SafeLogger.debug('player',
        'player_screen.dart:_onHorizontalDragEnd: swipe channel change (H-swipe) vx=$vx fromIdx=$idx toIdx=$nextIdx channel=${next.name}');
    if (!mounted) return;
    setState(() => _channelSwipeOverlay = next.name);
    Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _channelSwipeOverlay = null);
    });
    _scheduleChannelSwitch(next);
  }

  void _onRetryPressed() {
    final now = DateTime.now();
    if (_lastRetryAt != null &&
        now.difference(_lastRetryAt!) < const Duration(seconds: 2)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait...'),
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }
    _lastRetryAt = now;
    _failedLinks.clear();
    _failoverAttempts = 0;
    unawaited(_prepareLinksAndPlay());
  }

  void _onDragStart(DragStartDetails d) {
    final w = MediaQuery.of(context).size.width;
    _isDragging = true;
    _dragStartY = d.localPosition.dy;
    _draggingVolume = d.localPosition.dx > w / 2;
    _dragStartVal = _draggingVolume ? _volume : _brightness;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_isDragging) return;
    final playerH = MediaQuery.of(context).size.width * 9 / 16;
    final delta = (_dragStartY - d.localPosition.dy) / playerH;
    final newVal = (_dragStartVal + delta).clamp(0.0, 1.0);
    if (!mounted) return;
    setState(() {
      if (_draggingVolume) {
        _volume = newVal;
        _player.setVolume(_volume * 100);
      } else {
        _brightness = newVal;
        try {
          ScreenBrightness().setApplicationScreenBrightness(_brightness);
        } catch (_) {}
      }
      _indicatorOpacity = 1.0;
    });
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _indicatorOpacity = 0.0);
    });
  }

  void _onDragEnd(DragEndDetails _) => _isDragging = false;
  Widget _buildFullPlayerUi(BuildContext context) {
    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isFullscreen) _exitFullscreen();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0C),
        body: Column(children: [
          _buildPlayer(context),
          if (_links.length > 1 && !_isFullscreen)
            _buildStreamLinkStrip(context),
          if (!_isFullscreen) Expanded(child: _buildInfo(context)),
        ]),
      ),
    );
  }

  Widget _buildPlayer(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final double playerH;
    if (_isFullscreen) {
      playerH = size.height;
    } else {
      final ideal = size.width * 9 / 16;
      final maxH = (size.height * 0.58).clamp(280.0, double.infinity);
      playerH = ideal.clamp(280.0, maxH);
    }
    return GestureDetector(
      onTap: _toggleControls,
      onDoubleTapDown: _onDoubleTapDown,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Container(
        width: double.infinity,
        height: playerH,
        color: Colors.black,
        child: Stack(children: [
          // ── Video surface ──
          if (_hasError || (_currentUrl?.isEmpty ?? true))
            Center(
              child: PlayerErrorPanel(
                message: (_currentUrl?.isEmpty ?? true)
                    ? 'Stream link নেই'
                    : 'Stream load হয়নি',
                onRetry: _onRetryPressed,
              ),
            )
          else ...[
            // Mount Video before open — mpv needs a valid Android WinID.
            Positioned.fill(child: _buildVideoSurface()),
            if (!_initialized) Positioned.fill(child: _buildLoadingSkeleton()),
          ],

          // ── Buffering spinner ──
          ValueListenableBuilder<bool>(
            valueListenable: _bufferingVisible,
            builder: (context, buffering, _) {
              if (!buffering || _hasError || !_initialized) {
                return const SizedBox.shrink();
              }
              return const Center(child: PlayerSpinner());
            },
          ),

          if (_seekOverlayLabel != null && _seekOverlayOpacity > 0)
            _buildSeekOverlay(),

          if (_channelSwipeOverlay != null) _buildChannelSwipeOverlay(),

          // ── Controls overlay ──
          if (_showControls) ...[
            _buildTopBar(context),
            _buildControls(context),
          ],

          // ── Drag indicator ──
          if (_indicatorOpacity > 0) _buildDragIndicator(),

          // ── In-player video ad (YouTube-style skip after 5s, auto 5s) ──
          if (_showVideoAdOverlay)
            Positioned.fill(
              child: PlayerVideoAdOverlay(
                onDismiss: _dismissPlayerVideoAd,
                skipAfterSeconds: 15,
                maxDurationSeconds: 15,
              ),
            ),

          if (_pauseAdVisible &&
              !_isPlaying &&
              !_showVideoAdOverlay &&
              (AdConfig.hasAdsterraWebViewZones || MonetagConfig.isConfigured))
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  if (!mounted) return;
                  setState(() => _pauseAdVisible = false);
                },
                child: ColoredBox(
                  color: Colors.black.withValues(
                    alpha: AdConfig.playerAdsUserVisible ? 0.72 : 0,
                  ),
                  child: const Center(
                    child: AdsterraNativeBanner(
                      placement: 'pause_overlay',
                      height: 200,
                      userVisible: AdConfig.playerAdsUserVisible,
                    ),
                  ),
                ),
              ),
            ),

          if (AdPlacementConfig.showPlayerStickySocialBar &&
              AdManager.instance.adsEnabled &&
              _playbackSurfaceReady &&
              !_showVideoAdOverlay &&
              _isPlaying)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: RepaintBoundary(
                child: PlayerStickyAdStrip(key: _stickyAdKey),
              ),
            ),

          // ── Player overlay ad (15s delay, frequency-capped) ──
          if (AdManager.instance.adsEnabled &&
              _playbackSurfaceReady &&
              !_showVideoAdOverlay &&
              AdConfig.playerAdsUserVisible)
            PlayerOverlayAd(
              isStreaming: _isPlaying,
              isBuffering: _isBuffering,
              isPipMode: _isPipActive,
            ),
        ]),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 6,
          left: 4,
          right: 8,
          bottom: 14,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.92),
              Colors.black.withValues(alpha: 0.35),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () =>
                  _isFullscreen ? _exitFullscreen() : Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentTitle,
                    style: GF.head(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.subtitle.isNotEmpty)
                    Text(
                      widget.subtitle,
                      style: GF.body(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (_pipAvailable)
              IconButton(
                icon: Icon(Icons.picture_in_picture_alt_rounded,
                    color: Colors.white.withValues(alpha: 0.85), size: 22),
                tooltip: 'Mini player',
                onPressed: _enterPipNow,
              ),
            IconButton(
              icon: Icon(Icons.tune_rounded,
                  color: Colors.white.withValues(alpha: 0.9), size: 22),
              tooltip: 'Quality',
              onPressed: () => _showQualityDialog(context),
            ),
            if (_qualityBadge.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _playerOverlayChip(
                  child: Text(
                    _qualityBadge,
                    style: GF.body(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            _playerOverlayChip(
              fill: tokens.AppTokens.accent.withValues(alpha: 0.92),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PlayerLiveDot(),
                  const SizedBox(width: 5),
                  Text(
                    'LIVE',
                    style: GF.head(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    final prov = context.read<AppProvider>();
    final ch = prov.channelForStream(_currentUrl ?? '') ??
        prov.findChannel(name: _currentTitle);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ch != null)
            ChannelAvatar(channel: ch, size: 56)
          else
            Icon(
              Icons.live_tv_rounded,
              size: 56,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          const SizedBox(height: 14),
          Text(
            _currentTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            'Connecting to stream...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          PlayerConnectingDots(),
        ],
      ),
    );
  }

  Widget _buildSeekOverlay() {
    final isRewind = _seekOverlayLabel?.startsWith('⏪') ?? false;
    return Positioned(
      left: isRewind ? 24 : null,
      right: isRewind ? null : 24,
      top: 0,
      bottom: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _seekOverlayOpacity,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: Text(
              _seekOverlayLabel ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelSwipeOverlay() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          _channelSwipeOverlay ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildStreamLinkStrip(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0C),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _links.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final link = _links[i];
            final active = i == _activeLinkIndex;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _switchToLink(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  constraints:
                      const BoxConstraints(minWidth: 88, maxWidth: 140),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: active
                        ? tokens.AppTokens.accent
                        : const Color(0xFF14141A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active
                          ? tokens.AppTokens.accent
                          : const Color(0xFF252530),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    link.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GF.body(
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.72),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final isPlaying = _player.state.playing;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomPad),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.92),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProgressTimeRow(),
            const SizedBox(height: 10),
            Row(
              children: [
                PlayerTransportBtn(
                  icon: _fitModeIcon(),
                  tooltip: labelForPlayerFitMode(_fitMode),
                  onTap: _cycleFitMode,
                ),
                PlayerTransportBtn(
                  icon: Icons.replay_10_rounded,
                  onTap: () => _seek(-10),
                ),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: _togglePlay,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color:
                              tokens.AppTokens.accent.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: tokens.AppTokens.accent
                                  .withValues(alpha: 0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
                PlayerTransportBtn(
                  icon: Icons.forward_10_rounded,
                  onTap: () => _seek(10),
                ),
                PlayerTransportBtn(
                  icon: _isFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  onTap: () {
                    _toggleFullscreen();
                    _revealControls();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressTimeRow() {
    return StreamBuilder<Duration>(
      stream: _player.stream.position,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = _player.state.duration;
        final isLive = dur.inMilliseconds <= 0;
        final progress = isLive
            ? null
            : (dur.inMilliseconds > 0
                ? _safeUnitProgress(
                    pos.inMilliseconds / dur.inMilliseconds,
                  )
                : 0.0);
        final sliderValue = _safeUnitProgress(_scrubValue ?? progress ?? 0.0);

        return Column(
          children: [
            if (!isLive && dur.inMilliseconds > 0)
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: tokens.AppTokens.accent,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
                  thumbColor: tokens.AppTokens.accent,
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: sliderValue,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (v) {
                    if (!mounted) return;
                    setState(() => _scrubValue = _safeUnitProgress(v));
                  },
                  onChangeEnd: (v) {
                    final safe = _safeUnitProgress(v);
                    final maxMs = dur.inMilliseconds
                        .toDouble()
                        .clamp(1.0, double.infinity);
                    final targetMs =
                        (safe * maxMs).round().clamp(0, dur.inMilliseconds);
                    _player.seek(Duration(milliseconds: targetMs));
                    if (!mounted) return;
                    setState(() => _scrubValue = null);
                  },
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress != null ? _safeUnitProgress(progress) : null,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  valueColor:
                      const AlwaysStoppedAnimation(tokens.AppTokens.accent),
                  minHeight: 3,
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  _formatDuration(pos),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                Text(
                  isLive ? '● LIVE' : _formatDuration(dur),
                  style: TextStyle(
                    color: isLive
                        ? tokens.AppTokens.accent
                        : Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  Widget _buildDragIndicator() {
    final val = _draggingVolume ? _volume : _brightness;
    final icon = _draggingVolume
        ? (val == 0
            ? Icons.volume_off
            : val < 0.5
                ? Icons.volume_down
                : Icons.volume_up)
        : (val < 0.3
            ? Icons.brightness_low
            : val < 0.7
                ? Icons.brightness_medium
                : Icons.brightness_high);
    final color = _draggingVolume
        ? tokens.AppTokens.accent
        : Colors.yellow.withValues(alpha: 0.9);

    return Positioned(
      top: 0,
      bottom: 0,
      left: _draggingVolume ? null : 20,
      right: _draggingVolume ? 20 : null,
      child: Center(
        child: AnimatedOpacity(
          opacity: _indicatorOpacity,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 4,
                  height: 80,
                  color: Colors.white.withValues(alpha: 0.2),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: val,
                      child: Container(color: color),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(val * 100).toInt()}%',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    final prov = context.read<AppProvider>();
    final displayChannels = _relatedDisplay.isNotEmpty
        ? _relatedDisplay
        : (widget.relatedChannels ?? _defaultChannelsForCategory());
    final relatedTitle = AppProvider.relatedSectionLabel(_relatedCategory);

    return Container(
      color: const Color(0xFF0C0C0E),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollEndNotification) {
            _prefetchVisibleChannelPlaylists(displayChannels);
          }
          return false;
        },
        child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
            children: [
              // ── Now playing card ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF16161E), Color(0xFF101014)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2A2A36)),
                ),
                child: Row(children: [
                  Builder(
                    builder: (ctx) {
                      final ch = prov.channelForStream(_currentUrl ?? '') ??
                          prov.findChannel(name: _currentTitle);
                      if (ch != null) {
                        return ChannelAvatar(channel: ch, size: 52);
                      }
                      return Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A22),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            categoryEmoji(widget.category),
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentTitle,
                          style: GF.head(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.subtitle.isNotEmpty)
                          Text(
                            widget.subtitle,
                            style: GF.body(
                              color: tokens.AppTokens.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: tokens.AppTokens.accentMuted,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                tokens.AppTokens.accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const PlayerLiveDot(),
                            const SizedBox(width: 5),
                            Text(
                              'LIVE',
                              style: GF.head(
                                color: tokens.AppTokens.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _initialized
                            ? 'Now playing'
                            : _hasError
                                ? 'Unavailable'
                                : 'Connecting…',
                        style: GF.body(
                          color: _initialized
                              ? tokens.AppTokens.success
                              : _hasError
                                  ? tokens.AppTokens.danger
                                  : tokens.AppTokens.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              const PlayerAdSlot(),

              // ── Related channels header ──
              Text(
                relatedTitle,
                style: GF.head(
                  color: tokens.AppTokens.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 12),

              // ── Related channel cards ──
              ...displayChannels.map((ch) => PlayerRelatedCard(
                    channel: ch,
                    isPlaying: _currentUrl == ch.streamUrl,
                    onTap: () => _scheduleChannelSwitch(ch),
                  )),

              const SizedBox(height: 20),
            ]),
      ),
    );
  }

  List<({String label, int targetHeight, String? hint})>
      _parsedQualityChoices() {
    return const [
      (label: 'Auto', targetHeight: 0, hint: 'Adaptive'),
      (label: '180p', targetHeight: 180, hint: null),
      (label: '270p', targetHeight: 270, hint: null),
      (label: '360p', targetHeight: 360, hint: '704×396 · ~0.35 Mbps'),
      (label: '480p', targetHeight: 480, hint: null),
      (label: '540p', targetHeight: 540, hint: '960×540 · ~0.70 Mbps'),
      (label: '720p', targetHeight: 720, hint: null),
      (label: '1080p', targetHeight: 1080, hint: '1920×1080 · ~8.20 Mbps'),
    ];
  }

  IconData _qualityIconFor(String label) {
    if (label == 'Auto') return Icons.auto_awesome_rounded;
    final h = int.tryParse(label.replaceAll('p', '')) ?? 0;
    if (h >= 1080) return Icons.hd_rounded;
    if (h >= 720) return Icons.high_quality_rounded;
    return Icons.sd_rounded;
  }

  Widget _qualityOptionTile({
    required BuildContext ctx,
    required String label,
    required int targetHeight,
    required String? hint,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? tokens.AppTokens.accent.withValues(alpha: 0.14)
                : const Color(0xFF232A38),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? tokens.AppTokens.accent.withValues(alpha: 0.65)
                  : const Color(0xFF2E3648),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? tokens.AppTokens.accent.withValues(alpha: 0.22)
                      : const Color(0xFF1A1F2B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _qualityIconFor(label),
                  size: 22,
                  color: selected ? tokens.AppTokens.accent : Colors.white54,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hint != null && hint.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? tokens.AppTokens.accent : Colors.white24,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQualityDialog(BuildContext context) {
    _revealControls(restartTimer: false);
    if (_hlsVariants.isEmpty) {
      unawaited(_reloadMasterVariants());
    }
    final choices = _parsedQualityChoices();
    var pickHeight = _selectedTargetHeight;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final size = MediaQuery.sizeOf(ctx);
          final isLandscape = size.width > size.height;
          final dialogW = (size.width - 44).clamp(280.0, 400.0);
          // Landscape: height is the short edge — cap dialog to that edge, not list+header sum.
          final dialogH = isLandscape
              ? (size.height * 0.92).clamp(200.0, 380.0)
              : (size.height * 0.72).clamp(320.0, 560.0);
          // #region agent log
          _debugSessionLog(
            location: 'player_screen.dart:_showQualityDialog',
            message: 'quality dialog layout',
            hypothesisId: 'H-quality-overflow',
            data: {
              'viewW': size.width,
              'viewH': size.height,
              'isLandscape': isLandscape,
              'dialogW': dialogW,
              'dialogH': dialogH,
              'choiceCount': choices.length,
            },
          );
          // #endregion

          return Dialog(
            backgroundColor: const Color(0xFF1A1F2B),
            insetPadding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 28 : 22,
              vertical: isLandscape ? 12 : 28,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: SizedBox(
              width: dialogW,
              height: dialogH,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      isLandscape ? 12 : 18,
                      12,
                      isLandscape ? 8 : 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                tokens.AppTokens.accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: tokens.AppTokens.accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Stream Quality',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Choose playback resolution',
                                style: TextStyle(
                                  color: Color(0xFF8A94A8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                      height: 1, color: Colors.white.withValues(alpha: 0.08)),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      itemCount: choices.length,
                      separatorBuilder: (_, i) => i == 0
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color:
                                          Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      'MANUAL',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.35),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color:
                                          Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final c = choices[i];
                        final selected = pickHeight == c.targetHeight;
                        return _qualityOptionTile(
                          ctx: ctx,
                          label: c.label,
                          targetHeight: c.targetHeight,
                          hint: c.hint,
                          selected: selected,
                          onTap: () =>
                              setDialog(() => pickHeight = c.targetHeight),
                        );
                      },
                    ),
                  ),
                  Divider(
                      height: 1, color: Colors.white.withValues(alpha: 0.08)),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      isLandscape ? 8 : 10,
                      14,
                      isLandscape ? 10 : 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: () async {
                              final choice = choices.firstWhere(
                                (c) => c.targetHeight == pickHeight,
                                orElse: () => choices.first,
                              );
                              Navigator.pop(dialogCtx);
                              await _applyQuality(
                                choice.label,
                                choice.targetHeight,
                              );
                              if (mounted) _revealControls();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: tokens.AppTokens.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Apply',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<VideoTrack> get _selectableVideoTracks {
    return _player.state.tracks.video.where((t) => (t.h ?? 0) > 0).toList();
  }

  int _trackHeight(VideoTrack t) => t.h ?? 0;

  bool _heightMatchesTarget(int h, int targetH) =>
      h > 0 && (h == targetH || (h - targetH).abs() <= 24);

  VideoTrack? _findTrackForced(int targetH, List<VideoTrack> tracks) {
    if (tracks.isEmpty) return null;

    for (final t in tracks) {
      if (_heightMatchesTarget(_trackHeight(t), targetH)) return t;
    }

    VideoTrack? bestAtMost;
    var bestH = -1;
    for (final t in tracks) {
      final h = _trackHeight(t);
      if (h > 0 && h <= targetH && h > bestH) {
        bestH = h;
        bestAtMost = t;
      }
    }
    if (bestAtMost != null) return bestAtMost;

    VideoTrack? lowest;
    var minH = 99999;
    for (final t in tracks) {
      final h = _trackHeight(t);
      if (h > 0 && h < minH) {
        minH = h;
        lowest = t;
      }
    }
    return lowest;
  }

  Future<void> _applyQuality(String label, int targetH) async {
    if (!mounted || _applyingQuality) return;
    _applyingQuality = true;
    final sw = Stopwatch()..start();
    var applyPath = 'unknown';
    try {
      if (!mounted) return;
      setState(() {
        _selectedQuality = label;
        _selectedTargetHeight = targetH;
        if (label != 'Auto') _qualityBadge = label;
      });
      unawaited(_persistQualityPref(targetH));

      // #region agent log
      SafeLogger.debug('player',
          'player_screen.dart:_applyQuality: quality apply start (H-quality) label=$label targetH=$targetH hlsVariantCount=${_hlsVariants.length} videoTrackCount=${_player.state.tracks.video.length} selectableTrackCount=${_selectableVideoTracks.length} currentUrlTail=${_currentUrl?.split('/').last ?? ''} masterUrlTail=${_masterUrl.split('/').last}');
      // #endregion

      if (label == 'Auto') {
        applyPath = 'auto';
        _userOverrideQuality = false;
        _pendingTargetHeight = null;
        if (_currentUrl != _masterUrl) {
          await _openStreamUrl(_masterUrl, _activeHeaders);
          if (mounted) setState(() => _currentUrl = _masterUrl);
        }
        await _player.setVideoTrack(VideoTrack.auto());
        if (_lastMpvCapHeight != null) {
          await _applyMpvHeightCap(null);
        }
        _updateQualityBadge();
        unawaited(_runInitialBandwidthSample());
        // #region agent log
        _debugSessionLog(
          location: 'player_screen.dart:_applyQuality',
          message: 'quality apply done',
          hypothesisId: 'H-quality-speed',
          data: {'path': applyPath, 'elapsedMs': sw.elapsedMilliseconds},
        );
        // #endregion
        return;
      }

      _userOverrideQuality = true;
      _pendingTargetHeight = targetH;

      final selectable = _selectableVideoTracks;
      final allVideoTracks = _player.state.tracks.video;
      final tracks = selectable.isNotEmpty ? selectable : allVideoTracks;

      final forcedVariant = _hlsVariants.isNotEmpty
          ? HlsQualityService.pickVariantForced(_hlsVariants, targetH)
          : null;
      final forcedTrack =
          tracks.isNotEmpty ? _findTrackForced(targetH, tracks) : null;

      var tier1Ok = false;
      var tier2Ok = false;

      // Fast path: switch HLS rendition inside the same player (no full reload).
      if (forcedTrack != null) {
        applyPath = 'track';
        // #region agent log
        _debugSessionLog(
          location: 'player_screen.dart:_applyQuality',
          message: 'tier2 setVideoTrack',
          hypothesisId: 'H5-smooth-quality',
          data: {
            'targetH': targetH,
            'trackH': forcedTrack.h,
            'onMaster': _currentUrl == _masterUrl,
          },
        );
        // #endregion
        await _player.setVideoTrack(forcedTrack);
        tier2Ok = true;
        if (_lastMpvCapHeight != null) {
          await _applyMpvHeightCap(null);
        }
        SafeLogger.debug('player',
            'player_screen.dart:_applyQuality: tier2 media_kit track (H-tier2) trackH=${forcedTrack.h} trackW=${forcedTrack.w}');
      } else if (forcedVariant != null && forcedVariant.url != _currentUrl) {
        applyPath = 'url_reopen';
        await _openStreamUrl(forcedVariant.url, _activeHeaders);
        if (mounted) {
          setState(() => _currentUrl = forcedVariant.url);
          tier1Ok = true;
        }
        SafeLogger.debug('player',
            'player_screen.dart:_applyQuality: tier1 HLS rendition (H-tier1) urlTail=${forcedVariant.url.split('/').last} height=${forcedVariant.height}');
      }

      if (!tier2Ok) {
        if (tier1Ok) {
          applyPath = '$applyPath+vf';
          await _applyMpvHeightCap(targetH);
        } else {
          applyPath = 'vf_debounced';
          _scheduleMpvHeightCap(targetH);
        }
        SafeLogger.debug('player',
            'player_screen.dart:_applyQuality: tier3 MPV vf scheduled/applied (H-tier3) targetH=$targetH tier1=$tier1Ok tier2=$tier2Ok debounced=${!tier1Ok} sourceHeight=$_sourceHeight');
      }

      _pendingTargetHeight = null;
    } finally {
      _applyingQuality = false;
      if (mounted) {
        _updateQualityBadge();
        if (!mounted) return;
        setState(() {});
        // #region agent log
        _debugSessionLog(
          location: 'player_screen.dart:_applyQuality',
          message: 'quality apply done',
          hypothesisId: 'H-quality-speed',
          data: {
            'path': applyPath,
            'elapsedMs': sw.elapsedMilliseconds,
            'selectedQuality': _selectedQuality,
            'selectedTargetHeight': _selectedTargetHeight,
            'qualityBadge': _qualityBadge,
          },
        );
        // #endregion
      }
    }
  }

  List<ChannelModel> _defaultChannelsForCategory() {
    if (_relatedCategory == 'Sports') {
      return _PlayerScreenState._defaultSportsChannels;
    }
    if (_relatedCategory == 'Bangladesh' || _relatedCategory == 'Bangla') {
      return _PlayerScreenState._defaultBanglaChannels;
    }
    return _PlayerScreenState._defaultSportsChannels;
  }
}
