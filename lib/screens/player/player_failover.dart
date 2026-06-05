part of lumio_player;

// Retry + backup URL logic

extension _PlayerFailover on _PlayerScreenState {
  bool get _canRunFailover {
    if (_applyingQuality) return false;
    final until = _failoverSuppressedUntil;
    if (until != null && DateTime.now().isBefore(until)) return false;
    return true;
  }
  void _suppressFailoverFor(Duration duration) {
    _failoverSuppressedUntil = DateTime.now().add(duration);
    _resetBufferingWatchdog();
    _bufferingStartedAt = null;
  }
  void _resetBufferingWatchdog() {
    _bufferingStartedAt = null;
    _bufferingWatchdog?.cancel();
    _bufferingWatchdog = null;
  }
  void _scheduleFailoverCheck() {
    if (!_canRunFailover) return;
    _bufferingWatchdog?.cancel();
    _bufferingWatchdog = Timer(_PlayerScreenState._bufferingTimeout, () async {
      if (!mounted || _bufferingStartedAt == null || !_canRunFailover) return;
      if (DateTime.now().difference(_bufferingStartedAt!) < _PlayerScreenState._bufferingTimeout) {
        return;
      }
      if (_failoverAttempts >= _PlayerScreenState._maxFailoverAttempts) {
        _showFailoverExhaustedUi();
        return;
      }
      _failoverAttempts++;
      agentDebugLog(
        location: 'player_screen.dart:_scheduleFailoverCheck',
        message: 'buffering watchdog fired',
        hypothesisId: 'H-failover',
        data: {
          'attempt': _failoverAttempts,
          'linkIndex': _activeLinkIndex,
        },
      );
      await _attemptFailover();
    });
  }
  void _showFailoverExhaustedUi() {
    if (!mounted) return;
    agentDebugLog(
      location: 'player_screen.dart:_showFailoverExhaustedUi',
      message: 'all failover links exhausted',
      hypothesisId: 'H-failover',
      data: {'failedLinks': _failedLinks.toList()},
    );
    setState(() {
      _hasError = true;
      _isBuffering = false;
    });
  }
  Future<void> _retryCurrentLink() async {
    final url = _currentUrl ?? _masterUrl;
    if (url.isEmpty) return;
    _suppressFailoverFor(const Duration(seconds: 25));
    _failoverAttempts = 0;
    _failedLinks.clear();
    if (mounted) {
      setState(() {
        _hasError = false;
        _isBuffering = true;
      });
    }
    await _openStreamUrl(url, _activeHeaders);
  }
  Future<void> _attemptFailover() async {
    if (!mounted || !_canRunFailover) return;
    if (_lastFailoverAt != null &&
        DateTime.now().difference(_lastFailoverAt!) < _PlayerScreenState._failoverCooldown) {
      return;
    }
    _lastFailoverAt = DateTime.now();

    if (_links.length <= 1) {
      if (_failoverAttempts >= _PlayerScreenState._maxFailoverAttempts) {
        _showFailoverExhaustedUi();
        return;
      }
      _failoverAttempts++;
      if (await _trySchemeFlipForCurrentLink()) return;
      // #region agent log
      _debugSessionLog(
        location: 'player_screen.dart:_attemptFailover',
        message: 'retry single link',
        hypothesisId: 'H-failover-single',
        data: {'attempt': _failoverAttempts, 'urlTail': _masterUrl.split('/').last},
      );
      // #endregion
      await _retryCurrentLink();
      return;
    }
    if (await _trySchemeFlipForCurrentLink()) return;

    _failedLinks.add(_activeLinkIndex);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Switching to backup stream...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    for (var i = 1; i < _links.length; i++) {
      final next = (_activeLinkIndex + i) % _links.length;
      if (_failedLinks.contains(next)) continue;
      await _recordPlayerCrashlyticsError(
        Exception('player_failover_switch'),
        StackTrace.current,
        reason: 'failover_from_${_activeLinkIndex}_to_$next',
      );
      agentDebugLog(
        location: 'player_screen.dart:_attemptFailover',
        message: 'failover switch',
        hypothesisId: 'H-failover',
        data: {'from': _activeLinkIndex, 'to': next},
      );
      await _switchToLink(next);
      return;
    }
    _showFailoverExhaustedUi();
  }
  Future<bool> _trySchemeFlipForCurrentLink() async {
    final url = _currentUrl ?? _masterUrl;
    final alt = _schemeAlternateUrl(url);
    if (alt == null || alt == url) return false;
    if (_schemeFlipUsedForLink.contains(_activeLinkIndex)) return false;
    _schemeFlipUsedForLink.add(_activeLinkIndex);
    if (mounted) {
      setState(() {
        _masterUrl = alt;
        _currentUrl = alt;
        _hasError = false;
        _isBuffering = true;
      });
    }
    await _openStreamUrl(alt, _activeHeaders);
    return true;
  }
}
