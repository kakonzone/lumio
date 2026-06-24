part of lumio_player;

// State + lifecycle helpers

extension _PlayerState on _PlayerScreenState {
  Future<int> _onPlaybackTriggerReached(int minute) async {
    if (!mounted || !AdManager.instance.adsEnabled) return 0;
    
    // Determine number of ads to show
    final adsCount = minute == 50 ? 2 : 1;
    
    // Pause playback
    _player.pause();
    
    // Show custom rewarded ad overlay
    if (!mounted) return 0;
    
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomRewardedAdOverlay(
          totalAdsInChain: adsCount,
          onDismissed: () {
            // Resume playback after ad
            if (mounted && _initialized) {
              _player.play();
            }
          },
          onRewardEarned: () {
            // Optional: track reward earned
          },
        ),
        fullscreenDialog: true,
      ),
    );
    
    return adsCount;
  }
  Future<void> _loadPreferredQuality() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final h = prefs.getInt('preferred_quality_height');
      if (h != null && mounted) {
        setState(() {
          _selectedTargetHeight = h;
          _selectedQuality = h == 0 ? 'Auto' : '${h}p';
          _pendingTargetHeight = h == 0 ? null : h;
          _userOverrideQuality = h != 0;
        });
      } else if (mounted) {
        final device = _qualityDeviceClasses();
        final initialPx = QualityConfig.initialTargetHeightPx(
          isTablet: device.$1,
          isDesktop: device.$2,
        );
        setState(() {
          _selectedTargetHeight = initialPx;
          _selectedQuality = '${initialPx}p';
          _pendingTargetHeight = initialPx;
          _userOverrideQuality = false;
        });
      }
    } catch (e) {
      SafeLogger.debug('player', 'player_screen.dart:_loadPreferredQuality: prefs read failed: ${e.toString()}');
    }
  }

  Future<void> _ensureRelatedChannelsReady() async {
    if (_relatedCategory.toUpperCase() == 'GITUN') {
      await context.read<AppProvider>().ensureGitunChannelsLoaded();
    }
    if (!mounted) return;
    _refreshRelatedDisplay();
  }

  bool _relatedListEqual(List<ChannelModel> a, List<ChannelModel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _refreshRelatedDisplay() {
    if (!mounted) return;
    final list = context.read<AppProvider>().playerRelatedChannels(
          currentTitle: _currentTitle,
          currentUrl: _currentUrl,
          relatedCategory: _relatedCategory,
          fallback: widget.relatedChannels,
        );
    if (_relatedListEqual(list, _relatedDisplay)) return;
    setState(() => _relatedDisplay = list);
  }

  (bool, bool) _qualityDeviceClasses() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return (false, false);
    final view = views.first;
    final logicalShort = view.physicalSize.shortestSide / view.devicePixelRatio;
    return (logicalShort >= 600, false);
  }

  void _scheduleIdleWork() {
    _idleProbeSub?.cancel();
    _idleProbeSub = _player.stream.playing.listen((isPlaying) {
      if (isPlaying) return;
      final token = ++_idleWorkToken;
      Future<void>.delayed(const Duration(seconds: 5), () async {
        if (!mounted || token != _idleWorkToken) return;
        if (_player.state.playing) return;
        if (PlayerPlaybackIdleGate.shouldSkipBackgroundWork(
          isPlaying: _player.state.playing,
          isLowRam: PerformanceTuning.isLowRam,
        )) {
          return;
        }
        _probeRelatedChannels();
        await _prewarmMpvFilters();
      });
    });
  }

  void _probeRelatedChannels() {
    if (PlayerPlaybackIdleGate.shouldSkipBackgroundWork(
      isPlaying: _player.state.playing,
      isLowRam: PerformanceTuning.isLowRam,
    )) {
      debugPrint(
        _player.state.playing
            ? '[probe] skipped — playback active'
            : '[probe] skipped — low RAM device',
      );
      return;
    }
    if (!mounted || _probeInFlight) return;
    if (_relatedDisplay.isEmpty) return;
    _probeInFlight = true;
    final probe = _relatedDisplay.take(6).toList();
    context
        .read<AppProvider>()
        .ensureStreamHealth(probe, priority: false)
        .whenComplete(() {
      _probeInFlight = false;
    });
  }

  Future<void> _enableLeavePiP() async {
    if (_pipBlocked) return;
    try {
      await LumioWindowSecure.setSecure(false);
      final available = await _floating.isPipAvailable;
      if (!available) {
        _pipAvailable = false;
        _pipBlocked = true;
        if (mounted) setState(() {});
        return;
      }
      await _floating.enable(
        const OnLeavePiP(aspectRatio: Rational(16, 9)),
      );
      _pipAvailable = true;
      _pipConfigured = true;
      SafeLogger.debug('player', 'player_screen.dart:_enableLeavePiP: PiP on-leave enabled');
    } catch (e) {
      _pipAvailable = false;
      _pipConfigured = false;
      _pipBlocked = true;
      SafeLogger.debug('player', 'player_screen.dart:_enableLeavePiP: PiP enable failed: ${e.toString()}');
    }
    if (mounted) setState(() {});
  }

  Future<void> _enterPipNow() async {
    if (_pipBlocked || !_pipAvailable || !_initialized || _hasError) return;
    try {
      await LumioWindowSecure.setSecure(false);
      final status = await _floating.enable(
        const ImmediatePiP(aspectRatio: Rational(16, 9)),
      );
      // #region agent log
      _debugSessionLog(
        location: 'player_screen.dart:_enterPipNow',
        message: 'immediate pip',
        hypothesisId: 'H-pip',
        data: {'status': status.name},
      );
      // #endregion
    } catch (e) {
      _pipBlocked = true;
      _pipAvailable = false;
      if (mounted) setState(() {});
      _debugSessionLog(
        location: 'player_screen.dart:_enterPipNow',
        message: 'immediate pip failed',
        hypothesisId: 'H-pip',
        data: {'err': e.toString()},
      );
    }
  }

  Future<void> _keepPlaybackAliveInBackground() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (_) {}
    if (_player.state.playing) return;
    try {
      await _player.play();
    } catch (_) {}
  }

  void _cancelPendingOps() {
    _bufferingWatchdog?.cancel();
    _bufferingWatchdog = null;
    _bufferingStartedAt = null;
    _probeInFlight = false;
    _switchGeneration++;
    
    // Cancel all stream subscriptions
    _bufferingSub?.cancel();
    _bufferingSub = null;
    _errorSub?.cancel();
    _errorSub = null;
    _playingSub?.cancel();
    _playingSub = null;
    _positionSub?.cancel();
    _positionSub = null;
    _widthSub?.cancel();
    _widthSub = null;
    _heightSub?.cancel();
    _heightSub = null;
    _tracksSub?.cancel();
    _tracksSub = null;
    _idleProbeSub?.cancel();
    _idleProbeSub = null;
    
    // Cancel all timers (excluding those managed by dispose)
    _qualityDebounce?.cancel();
    _qualityDebounce = null;
    _autoQualityTimer?.cancel();
    _autoQualityTimer = null;
    _channelSwitchDebounce?.cancel();
    _channelSwitchDebounce = null;
    
    // Reset playback time tracker
    _playbackTimeTracker.reset();
  }

  void _startAutoQualityTimer() {
    _autoQualityTimer?.cancel();
    _autoQualityTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted || _userOverrideQuality || _selectedTargetHeight != 0) {
        return;
      }
      if (_isBuffering && _bufferingStartedAt != null) {
        unawaited(_evaluateAutoQuality(downgrade: true));
      } else if (_stablePlaybackTicks >= 4) {
        unawaited(_evaluateAutoQuality(stepUp: true));
        _stablePlaybackTicks = 0;
      }
    });
  }

  Future<void> _refreshConnectivityHint() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _isOnWifi = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
      if (_isOnWifi) {
        _estimatedMbps = 8.0;
      } else if (results.contains(ConnectivityResult.mobile)) {
        _estimatedMbps = 2.0;
      } else if (results.contains(ConnectivityResult.none)) {
        _estimatedMbps = 0.3;
      }
      try {
        _batteryPercent = await _PlayerScreenState._qualityBattery.batteryLevel;
      } catch (_) {}
    } catch (e) {
      SafeLogger.debug('player', 'player_screen.dart:_refreshConnectivityHint: connectivity check failed: ${e.toString()}');
    }
  }

  Future<void> _runInitialBandwidthSample() async {
    await _refreshConnectivityHint();
    var bufferingMs = 0;
    DateTime? bufferStartTime;
    late final StreamSubscription<bool> bufSub;
    bufSub = _player.stream.buffering.listen((b) {
      if (b) {
        bufferStartTime = DateTime.now();
      } else if (bufferStartTime != null) {
        bufferingMs += DateTime.now()
            .difference(bufferStartTime!)
            .inMilliseconds;
        bufferStartTime = null;
      }
    });
    await Future.delayed(const Duration(seconds: 5));
    await bufSub.cancel();
    if (!mounted) return;
    if (bufferingMs > 2500) {
      _estimatedMbps = (_estimatedMbps * 0.45).clamp(0.2, 20.0);
    } else if (bufferingMs < 400) {
      _estimatedMbps = (_estimatedMbps * 1.25).clamp(0.2, 20.0);
    }
    SafeLogger.debug('player', 'player_screen.dart:_runInitialBandwidthSample: bandwidth sample done, mbps: $_estimatedMbps, bufferingMs: $bufferingMs');
    await _evaluateAutoQuality();
  }

  Future<void> _evaluateAutoQuality({
    bool downgrade = false,
    bool stepUp = false,
  }) async {
    if (!mounted || _userOverrideQuality || _selectedTargetHeight != 0) {
      return;
    }
    if (_hlsVariants.isEmpty) return;
    if (stepUp && !downgrade) {
      await _refreshConnectivityHint();
    }
    if (downgrade) {
      _estimatedMbps = (_estimatedMbps * 0.7).clamp(0.2, 20.0);
    }
    var variant = HlsQualityService.pickVariantForAuto(
      _hlsVariants,
      _estimatedMbps,
      downgrade: downgrade,
    );
    if (variant == null) return;
    final clampedH = QualityConfig.clampAutoHeightPx(
      targetHeightPx: variant.height,
      isMobile: QualityConfig.isMobilePlatform,
      isOnWifi: _isOnWifi,
      batteryPercent: _batteryPercent,
    );
    if (clampedH != variant.height) {
      variant = HlsQualityService.pickVariantForced(_hlsVariants, clampedH) ??
          variant;
    }
    SafeLogger.debug('player', 'player_screen.dart:_evaluateAutoQuality: auto tier selected, mbps: $_estimatedMbps, height: ${variant.height}, downgrade: $downgrade, stepUp: $stepUp');
    await _applyAutoVariant(variant);
  }

  Future<void> _applyAutoVariant(HlsVariant variant) async {
    if (!mounted || _applyingQuality) return;
    _applyingQuality = true;
    try {
      if (_currentUrl == _masterUrl && _player.state.tracks.video.isNotEmpty) {
        final tracks = _selectableVideoTracks;
        final match = _findTrackForced(variant.height, tracks);
        if (match != null) {
          await _player.setVideoTrack(match);
          _updateQualityBadge();
          return;
        }
      }
      if (variant.url != _currentUrl) {
        await _openStreamUrl(variant.url, _activeHeaders);
        if (mounted) setState(() => _currentUrl = variant.url);
      }
      _updateQualityBadge();
    } finally {
      _applyingQuality = false;
    }
  }

  Future<void> _prepareLinksAndPlay() async {
    SafeLogger.debug('player', 'player_screen.dart:_prepareLinksAndPlay: prepare start, linkCount: ${_links.length}, labels: ${_links.map((l) => l.label).toList()}');
    if (!mounted) return;
    _warmAlternateLinks();
    await _bootstrapPlayback();

    if (_links.length > 1) {
      unawaited(_rankLinksInBackground());
    }
  }

  void _warmAlternateLinks() {
    if (_links.length <= 1) return;
    for (var i = 1; i < _links.length && i < 3; i++) {
      final link = _links[i];
      final uri = Uri.tryParse(link.url);
      if (uri == null || !uri.hasScheme) continue;
      unawaited(
        http
            .head(uri, headers: {
              'User-Agent': link.headers?['User-Agent'] ??
                  'Mozilla/5.0 LumioTV/1.0',
            })
            .timeout(const Duration(seconds: 3))
            .catchError((_) => http.Response('', 599)),
      );
    }
  }

  Future<void> _rankLinksInBackground() async {
    await Future.delayed(const Duration(seconds: 15));
    if (!mounted || _isBuffering || !_player.state.playing) return;
    final gen = _switchGeneration;
    final ranked = await StreamLinkRankerService.rankBySpeed(_links);
    if (!mounted || gen != _switchGeneration) return;
    if (ranked.first.url == _masterUrl) return;
    SafeLogger.debug('player', 'player_screen.dart:_rankLinksInBackground: switching to faster link, label: ${ranked.first.label}');
    setState(() {
      _links = ranked;
      _activeLinkIndex = 0;
      _masterUrl = ranked.first.url;
      _currentUrl = ranked.first.url;
      _activeHeaders = ranked.first.headers;
    });
    await _bootstrapPlayback(skipOpen: true);
  }

  Future<void> _bootstrapPlayback({bool skipOpen = false}) async {
    _suppressFailoverFor(const Duration(seconds: 25));
    final variants = await HlsQualityService.fetchVariantsFast(
      _masterUrl,
      headers: _activeHeaders,
    );
    var openUrl = _masterUrl;
    if (_pendingTargetHeight != null &&
        _pendingTargetHeight! > 0 &&
        variants.isNotEmpty) {
      final preferred = HlsQualityService.pickVariantForced(
          variants, _pendingTargetHeight!);
      openUrl = preferred?.url ?? _masterUrl;
    } else {
      final low = HlsQualityService.lowestVariant(variants);
      if (low != null && low.url.isNotEmpty) openUrl = low.url;
    }
    _currentUrl = openUrl;
    if (!mounted) return;
    setState(() => _hlsVariants = variants);
    if (!skipOpen) {
      await _initPlayer(openUrl, _activeHeaders);
    }
    if (!mounted) return;

    if (_pendingTargetHeight != null && _pendingTargetHeight! > 0) {
      // Let the first frame render before track/quality switches (avoids vo races).
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      await _applyQuality(_selectedQuality, _pendingTargetHeight!);
      _pendingTargetHeight = null;
    } else if (!_userOverrideQuality && _selectedTargetHeight == 0) {
      unawaited(_runInitialBandwidthSample());
    }
  }

  Future<void> _reloadMasterVariants() async {
    final variants = await HlsQualityService.fetchVariants(
      _masterUrl,
      headers: _activeHeaders,
    );
    if (mounted) setState(() => _hlsVariants = variants);
  }

  void _attachListeners() {
    // Cancel existing subscriptions before creating new ones (defensive)
    _bufferingSub?.cancel();
    _errorSub?.cancel();
    _playingSub?.cancel();
    _positionSub?.cancel();
    _widthSub?.cancel();
    _heightSub?.cancel();
    _tracksSub?.cancel();
    
    _bufferingSub = _player.stream.buffering.listen((isBuffering) {
      if (!mounted) return;
      _isBuffering = isBuffering;
      if (_bufferingVisible.value != isBuffering) {
        _bufferingVisible.value = isBuffering;
      }
      if (isBuffering) {
        if (!_canRunFailover) {
          _resetBufferingWatchdog();
          return;
        }
        _bufferingStartedAt = DateTime.now();
        _scheduleFailoverCheck();
      } else {
        _bufferingStartedAt = null;
        _bufferingWatchdog?.cancel();
        _bufferingWatchdog = null;
        if (_failoverAttempts > 0) _failoverAttempts = 0;
      }
    });
    _errorSub = _player.stream.error.listen((e) {
      if (!mounted || e.isEmpty) return;
      debugPrint('[player error] $e');
      if (!_canRunFailover) return;
      if (_failoverAttempts < _PlayerScreenState._maxFailoverAttempts) {
        unawaited(_attemptFailover());
        return;
      }
      setState(() {
        _hasError = true;
        _isBuffering = false;
      });
    });
    _playingSub = _player.stream.playing.listen((playing) {
      if (!mounted) return;
      if (playing) {
        _isPlaying = true;
        _playbackStartedAt ??= DateTime.now();
        StreamingState.setStreaming(true);
        if (_pauseAdVisible) {
          setState(() => _pauseAdVisible = false);
        }
        _resetBufferingWatchdog();
        _stablePlaybackTicks++;
        if (_initialized && !_pipConfigured) {
          unawaited(_enableLeavePiP());
        }
        // Start playback time tracker
        _playbackTimeTracker.start();
      } else {
        _isPlaying = false;
        StreamingState.setStreaming(false);
        _stablePlaybackTicks = 0;
        _onPlayerPaused();
        // Pause playback time tracker
        _playbackTimeTracker.pause();
      }
    });
    _positionSub = _player.stream.position.listen((_) {
      _resetBufferingWatchdog();
    });
    _widthSub = _player.stream.width.listen((_) => _updateQualityBadge());
    _heightSub = _player.stream.height.listen((h) {
      if (h != null && h > 0) {
        final prev = _sourceHeight;
        _sourceHeight = h;
        if (prev != h && mounted && _initialized) {
          setState(() {});
        }
      }
      _updateQualityBadge();
    });
    _tracksSub = _player.stream.tracks.listen((_) {
      if (!mounted || _applyingQuality) return;
      _updateQualityBadge();
    });
  }

  Future<void> _recordPlayerCrashlyticsError(
    Object error,
    StackTrace stackTrace, {
    required String reason,
  }) async {
    if (!FirebaseBootstrap.crashlyticsWired) return;
    final host = Uri.tryParse(_currentUrl ?? _masterUrl)?.host ?? 'unknown';
    await FirebaseCrashlytics.instance.setCustomKey('channel_id', widget.title);
    await FirebaseCrashlytics.instance.setCustomKey('stream_url_host', host);
    await FirebaseCrashlytics.instance.setCustomKey(
      'player_state',
      _initialized ? 'initialized' : 'booting',
    );
    await FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      reason: reason,
    );
  }

  bool get _isSingleRenditionStream {
    if (_hlsVariants.length > 1) return false;
    return _selectableVideoTracks.isEmpty;
  }

  void _refreshSourceHeight() {
    final h = _player.state.height ?? 0;
    if (h > 0) {
      _sourceHeight = h;
      return;
    }
    var maxH = 0;
    for (final t in _selectableVideoTracks) {
      final th = t.h ?? 0;
      if (th > maxH) maxH = th;
    }
    if (maxH > 0) _sourceHeight = maxH;
  }

  Future<void> _configureMpvOnce() async {
    if (_mpvNativeConfigured || _player.platform is! NativePlayer) return;
    final n = _player.platform as NativePlayer;
    try {
      // Player tuning (WC hotfix):
      // - mediacodec hwdec on Android avoids MIUI/ColorOS software fallback
      // - vf scale removed on mobile; mediacodec handles native output
      // - software scaling on 720p+ HLS = thermal throttle within 10 min
      await n.setProperty('cache', 'yes');
      await n.setProperty('cache-secs', '2');
      await n.setProperty('cache-pause-initial', 'no');
      await n.setProperty('demuxer-readahead-secs', '1');
      await n.setProperty('demuxer-max-bytes', '8MiB');
      await n.setProperty('demuxer-max-back-bytes', '2MiB');
      await n.setProperty('hls-bitrate', 'min');
      if (Platform.isAndroid) {
        // hwdec only — media_kit_video owns vo/wid via the Flutter [Video] surface.
        // Setting vo=gpu + gpu-context=android triggers vo_android_init without WinID → SIGABRT.
        await n.setProperty('hwdec', 'mediacodec');
        await n.setProperty('hwdec-codecs', 'h264,hevc,vp9,av1');
      } else {
        await n.setProperty('hwdec', 'auto-safe');
      }
      await n.setProperty('vd-lavc-fast', 'yes');
      await n.setProperty('vd-lavc-threads', '0');
      _mpvNativeConfigured = true;
    } catch (_) {}
  }

  int _defaultPrewarmCap() {
    _refreshSourceHeight();
    if (_sourceHeight <= 0) return 720;
    if (_sourceHeight >= 720) return 720;
    final below = _sourceHeight - 24;
    return below.clamp(180, _sourceHeight - 1);
  }

  Future<void> _prewarmMpvFilters() async {
    if (PerformanceTuning.isLowRam) {
      debugPrint('[prewarm] skipped — low RAM');
      return;
    }
    if (_player.state.playing) {
      debugPrint('[prewarm] skipped — playback active');
      return;
    }
    if (_player.platform is! NativePlayer || _vfPrewarmed || _isBuffering) {
      return;
    }
    _suppressFailoverFor(const Duration(seconds: 12));
    final warmH = _defaultPrewarmCap();
    final sw = Stopwatch()..start();
    await _applyMpvHeightCap(warmH);
    _vfPrewarmed = true;
    // #region agent log
    _debugSessionLog(
      location: 'player_screen.dart:_prewarmMpvFilters',
      message: 'vf prewarm done',
      hypothesisId: 'H-mono-prewarm',
      data: {
        'warmH': warmH,
        'sourceHeight': _sourceHeight,
        'elapsedMs': sw.elapsedMilliseconds,
      },
    );
    // #endregion
  }

  void _scheduleMpvHeightCap(int? height) {
    _suppressFailoverFor(const Duration(seconds: 10));
    _pendingVfHeight = height;
    _qualityDebounce?.cancel();
    _qualityDebounce = Timer(const Duration(milliseconds: 150), () {
      final pending = _pendingVfHeight;
      _pendingVfHeight = null;
      unawaited(_applyMpvHeightCap(pending));
    });
  }

  Future<void> _waitForVideoSurface() async {
    if (_videoSurfaceMounted) return;
    if (!mounted) return;
    if (_hasError || (_currentUrl?.isEmpty ?? true)) return;

    // Ensure [Video] is in the tree, then wait for native surface attachment.
    setState(() {});
    for (var i = 0; i < 4; i++) {
      final gate = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!gate.isCompleted) gate.complete();
      });
      await gate.future;
      if (!mounted) return;
    }
    // media_kit attaches wid asynchronously after platform view creation.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _videoSurfaceMounted = true);
  }

  Future<void> _openStreamUrl(String url, Map<String, String>? headers) async {
    if (!mounted) return;
    _suppressFailoverFor(const Duration(seconds: 25));
    setState(() {
      _isBuffering = true;
      _hasError = false;
    });
    try {
      await _waitForVideoSurface();
      if (!mounted) return;
      await _configureMpvOnce();
      final httpHeaders = {
        'User-Agent': 'Mozilla/5.0 LumioTV/1.0',
        ...?headers,
      };
      await _player.setVolume(_volume * 100);
      await _player
          .open(Media(url, httpHeaders: httpHeaders), play: true)
          .timeout(_PlayerScreenState._connectTimeout);
      if (mounted) {
        setState(() {
          _initialized = true;
          _playbackSurfaceReady = true;
        });
        _initBufferingWatchdog();
        _updateQualityBadge();
      }
    } catch (e, st) {
      await _recordPlayerCrashlyticsError(
        e,
        st,
        reason: 'player_open_stream_failed',
      );
      if (mounted) {
        setState(() {
          _hasError = true;
          _isBuffering = false;
        });
      }
      SafeLogger.error('player', 'player_screen.dart:_openStreamUrl: open failed', e);
    }
  }

  Future<void> _persistQualityPref(int targetH) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('preferred_quality_height', targetH);
    } catch (e) {
      if (kDebugMode)
        SafeLogger.error('player', 'player_screen.dart:_persistQualityPref: prefs write failed', e);
    }
  }

  Future<void> _applyMpvHeightCap(int? height) async {
    _suppressFailoverFor(const Duration(seconds: 10));
    final player = _player;
    if (player.platform is! NativePlayer) {
      SafeLogger.debug('player', 'player_screen.dart:_applyMpvHeightCap: non-native platform, skip (H-tier3)');
      return;
    }
    final cap = (height == null || height <= 0) ? null : height;
    if (cap == _lastMpvCapHeight) return;
    final native = player.platform as NativePlayer;
    final sw = Stopwatch()..start();
    try {
      if (cap == null) {
        await native.setProperty('vf', '');
        _lastMpvCapHeight = null;
        if (kDebugMode)
          SafeLogger.debug('player', 'player_screen.dart:_applyMpvHeightCap: vf cleared (Auto) (H-tier3)');
        return;
      }
      _refreshSourceHeight();
      if (_sourceHeight > 0 && cap >= _sourceHeight) {
        if (_lastMpvCapHeight != null) {
          await native.setProperty('vf', '');
          _lastMpvCapHeight = null;
        }
        // #region agent log
        _debugSessionLog(
          location: 'player_screen.dart:_applyMpvHeightCap',
          message: 'vf skipped at source resolution',
          hypothesisId: 'H-mono-skip-vf',
          data: {'cap': cap, 'sourceHeight': _sourceHeight},
        );
        // #endregion
        return;
      }
      if (Platform.isAndroid) {
        // WC hotfix: no CPU vf scale on Android — use HLS/track selection only.
        _lastMpvCapHeight = cap;
        return;
      }
      final filter = 'scale=-2:min($cap\\,ih):flags=fast_bilinear';
      // #region agent log
      _debugSessionLog(
        location: 'player_screen.dart:_applyMpvHeightCap',
        message: 'vf filter apply',
        hypothesisId: 'H1-vf-comma',
        data: {'height': cap, 'filter': filter},
      );
      // #endregion
      await native.setProperty('vf', filter);
      _lastMpvCapHeight = cap;
      // #region agent log
      _debugSessionLog(
        location: 'player_screen.dart:_applyMpvHeightCap',
        message: 'vf applied',
        hypothesisId: 'H-quality-speed',
        data: {
          'cap': cap,
          'sourceHeight': _sourceHeight,
          'elapsedMs': sw.elapsedMilliseconds,
        },
      );
      // #endregion
      SafeLogger.debug('player', 'player_screen.dart:_applyMpvHeightCap: vf scale applied (H-tier3) height=$cap filter=$filter');
    } catch (e, st) {
      SafeLogger.error('player', 'player_screen.dart:_applyMpvHeightCap: failed', e, st);
    }
  }

  Future<void> _loadBrightness() async {
    try {
      final b = await ScreenBrightness().current;
      if (mounted) setState(() => _brightness = b);
    } catch (_) {}
  }

  Future<void> _initPlayer(String url, Map<String, String>? headers) async {
    if (!mounted) return;
    setState(() {
      if (!_playbackSurfaceReady) _initialized = false;
      _hasError = false;
      _isBuffering = true;
    });
    try {
      await _openStreamUrl(url, headers);
    } catch (e, st) {
      await _recordPlayerCrashlyticsError(
        e,
        st,
        reason: 'player_init_failed',
      );
      rethrow;
    }
    if (mounted && _initialized) {
      SafeLogger.debug('player', 'player_screen.dart:_initPlayer: Player ready (H-player-ready) urlTail=${url.split('/').last}');
    }
  }

  void _initBufferingWatchdog() {
    SafeLogger.debug('player', 'player_screen.dart:_initBufferingWatchdog: watchdog armed (H-failover) linkIndex=$_activeLinkIndex');
  }

  List<StreamLink> _resolveStreamLinks() {
    final fromWidget =
        widget.streamLinks?.where((l) => l.url.isNotEmpty).toList() ?? [];
    final visible = fromWidget
        .where((l) => !ChannelModel.isInternalStreamLabel(l.label))
        .toList();
    if (visible.isNotEmpty) return visible;
    if (widget.streamUrl.isNotEmpty) {
      return [
        StreamLink(
          url: widget.streamUrl,
          label: 'Link 1',
          headers: widget.headers ?? const {'User-Agent': mozillaUA},
        ),
      ];
    }
    return [];
  }

  String? _schemeAlternateUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.scheme == 'https') {
      return uri.replace(scheme: 'http').toString();
    }
    if (uri.scheme == 'http') {
      return uri.replace(scheme: 'https').toString();
    }
    return null;
  }

  Future<void> _switchToLink(int index) async {
    if (index < 0 || index >= _links.length) return;
    _cancelPendingOps();
    _suppressFailoverFor(const Duration(seconds: 25));
    _lastFailoverAt = null;
    final link = _links[index];
    _failedLinks.clear();
    _failoverAttempts = 0;
    _schemeFlipUsedForLink.clear();
    setState(() {
      _activeLinkIndex = index;
      _masterUrl = link.url;
      _currentUrl = link.url;
      _activeHeaders = link.headers;
      _initialized = false;
      _hasError = false;
      if (!_userOverrideQuality) {
        _selectedQuality = 'Auto';
        _selectedTargetHeight = 0;
        _pendingTargetHeight = null;
      }
      _hlsVariants = [];
      _lastMpvCapHeight = null;
      _vfPrewarmed = false;
      _sourceHeight = 0;
      _qualityDebounce?.cancel();
    });
    await _bootstrapPlayback();
    if (mounted) _refreshRelatedDisplay();
  }

  void _scheduleChannelSwitch(ChannelModel ch) {
    _debouncedChannel = ch;
    _channelSwitchDebounce?.cancel();
    _channelSwitchDebounce = Timer(const Duration(milliseconds: 300), () {
      final target = _debouncedChannel;
      if (target == null || !mounted) return;
      unawaited(_switchChannel(target));
    });
  }

  Future<void> _switchChannel(ChannelModel ch) async {
    final currentToken = ++_switchToken;
    // #region agent log
    _debugSessionLog(
      location: 'player_screen.dart:_switchChannel',
      message: 'channel switch started',
      hypothesisId: 'H6-switch',
      data: {'token': currentToken, 'channel': ch.name},
    );
    // #endregion
    
    _cancelPendingOps();
    try {
      await _player.stop();
      // #region agent log
      _debugSessionLog(
        location: 'player_screen.dart:_switchChannel',
        message: 'player stopped before switch',
        hypothesisId: 'H6-stop',
      );
      // #endregion
    } catch (_) {}
    
    // Guard against re-entrancy: if token changed, this switch is stale
    if (currentToken != _switchToken) {
      // #region agent log
      _debugSessionLog(
        location: 'player_screen.dart:_switchChannel',
        message: 'switch cancelled (stale)',
        hypothesisId: 'H6-switch',
        data: {'token': currentToken, 'currentToken': _switchToken},
      );
      // #endregion
      return;
    }
    
    final links = context.read<AppProvider>().playbackLinksFor(ch);
    if (links.isEmpty) return;
    final first = links.first;
    if (mounted) {
      setState(() {
        _links = links;
        _activeLinkIndex = 0;
        _masterUrl = first.url;
        _currentUrl = first.url;
        _currentTitle = ch.name;
        _relatedCategory = context.read<AppProvider>().categoryForRelated(
              ch,
              browseCategory:
                  _relatedCategory.toUpperCase() == 'GITUN' ? 'GITUN' : null,
            );
        _relatedDisplay = const [];
        _initialized = false;
        _hasError = false;
        _activeHeaders = first.headers;
        if (!_userOverrideQuality) {
          _selectedQuality = 'Auto';
          _selectedTargetHeight = 0;
          _pendingTargetHeight = null;
        }
        _hlsVariants = [];
        _lastMpvCapHeight = null;
        _vfPrewarmed = false;
        _sourceHeight = 0;
        _qualityDebounce?.cancel();
      });
      _syncBackgroundNowPlaying();
    }
    _failedLinks.clear();
    _failoverAttempts = 0;
    _stablePlaybackTicks = 0;
    
    // Re-attach listeners with fresh subscriptions
    _attachListeners();
    
    await _bootstrapPlayback();
    
    // Guard against re-entrancy: check token again after async operations
    if (currentToken != _switchToken) {
      // #region agent log
      _debugSessionLog(
        location: 'player_screen.dart:_switchChannel',
        message: 'switch cancelled after bootstrap (stale)',
        hypothesisId: 'H6-switch',
        data: {'token': currentToken, 'currentToken': _switchToken},
      );
      // #endregion
      return;
    }
    
    unawaited(_ensureRelatedChannelsReady());
    if (links.length > 1) {
      unawaited(_rankLinksInBackground());
    }
    
    // #region agent log
    _debugSessionLog(
      location: 'player_screen.dart:_switchChannel',
      message: 'channel switch complete',
      hypothesisId: 'H6-switch',
      data: {'token': currentToken, 'channel': ch.name},
    );
    // #endregion
  }

  void _prefetchVisibleChannelPlaylists(List<ChannelModel> channels) {
    final headers = _activeHeaders;
    for (final ch in channels.take(8)) {
      final url = ch.streamUrl;
      if (url.contains('.m3u8')) {
        unawaited(
          HlsQualityService.prefetchPlaylistHead(url, headers: headers),
        );
      }
    }
  }

  Future<void> _bindBackgroundPlayback() async {
    try {
      final handler = await ensureLumioAudioService();
      handler.attachPlayer(_player);
      handler.setNowPlaying(
        title: _currentTitle.isNotEmpty ? _currentTitle : widget.title,
        mediaId: _currentUrl,
      );
      // #region agent log
      _debugSessionLog(
        location: 'player_screen.dart:_bindBackgroundPlayback',
        message: 'audio_service attached',
        hypothesisId: 'H2-audio-service',
        data: {'title': _currentTitle, 'hasUrl': _currentUrl != null},
      );
      // #endregion
    } catch (e) {
      // #region agent log
      _debugSessionLog(
        location: 'player_screen.dart:_bindBackgroundPlayback',
        message: 'audio_service attach failed',
        hypothesisId: 'H2-audio-service',
        data: {'err': e.toString()},
      );
      // #endregion
    }
  }

  void _syncBackgroundNowPlaying() {
    lumioAudioHandlerOrNull?.setNowPlaying(
      title: _currentTitle,
      mediaId: _currentUrl,
    );
  }
}
