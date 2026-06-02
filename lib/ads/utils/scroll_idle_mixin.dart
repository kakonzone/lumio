import 'dart:async';

import 'package:flutter/material.dart';

import '../state/scroll_idle_notifier.dart';

/// Reusable scroll-idle tracking for any screen with a [ScrollController].
mixin ScrollIdleMixin<T extends StatefulWidget> on State<T> {
  ScrollController? scrollIdleController;
  ScrollIdleNotifier? scrollIdleNotifier;

  Timer? _scrollIdlePoll;
  Duration scrollIdleThreshold = const Duration(seconds: 30);

  /// Call from [initState] after creating [controller].
  void initScrollIdle({
    required ScrollController controller,
    ScrollIdleNotifier? notifier,
    Duration? idleAfter,
    VoidCallback? onIdle,
  }) {
    scrollIdleController = controller;
    scrollIdleNotifier = notifier;
    if (idleAfter != null) scrollIdleThreshold = idleAfter;

    void handleScroll() {
      scrollIdleNotifier?.onUserScroll();
      _armIdleTimer(onIdle);
    }

    controller.addListener(handleScroll);
    _armIdleTimer(onIdle);
  }

  void _armIdleTimer(VoidCallback? onIdle) {
    _scrollIdlePoll?.cancel();
    _scrollIdlePoll = Timer(scrollIdleThreshold, () {
      if (!mounted) return;
      onIdle?.call();
    });
  }

  /// Wrap list content to catch scroll without an explicit controller.
  Widget wrapScrollIdleDetector({
    required Widget child,
    required ScrollIdleNotifier notifier,
  }) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification ||
            notification is ScrollStartNotification) {
          notifier.onUserScroll();
        }
        return false;
      },
      child: child,
    );
  }

  @override
  void dispose() {
    _scrollIdlePoll?.cancel();
    super.dispose();
  }
}
