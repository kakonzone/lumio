import 'dart:async';
import 'package:flutter/material.dart';

/// Debounce and throttle utilities
///
/// Provides performance optimization for frequently called operations.
class DebounceThrottle {
  /// Debounce a function call
  ///
  /// Delays execution until after wait milliseconds have elapsed
  /// since the last time the debounced function was invoked.
  static Function debounce(
    Function callback, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    Timer? timer;

    return () {
      if (timer?.isActive ?? false) {
        timer?.cancel();
      }

      timer = Timer(duration, callback as void Function());
    };
  }

  /// Debounce a function with parameter
  static Function debounceWithParam(
    Function callback, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    Timer? timer;

    return (param) {
      if (timer?.isActive ?? false) {
        timer?.cancel();
      }

      timer = Timer(duration, () => callback(param));
    };
  }

  /// Throttle a function call
  ///
  /// Executes function at most once every wait milliseconds.
  static Function throttle(
    Function callback, {
    Duration duration = const Duration(milliseconds: 100),
  }) {
    var isThrottled = false;
    Timer? timer;

    return () {
      if (isThrottled) return;

      callback();
      isThrottled = true;

      timer?.cancel();
      timer = Timer(duration, () {
        isThrottled = false;
      });
    };
  }

  /// Throttle a function with parameter
  static Function throttleWithParam(
    Function callback, {
    Duration duration = const Duration(milliseconds: 100),
  }) {
    var isThrottled = false;
    Timer? timer;

    return (param) {
      if (isThrottled) return;

      callback(param);
      isThrottled = true;

      timer?.cancel();
      timer = Timer(duration, () {
        isThrottled = false;
      });
    };
  }

  /// Frame-rate throttled function (16ms)
  ///
  /// Executes at most once per frame (60fps).
  /// Use for gestures like brightness/volume sliders.
  static Function throttleFrame(Function callback) {
    return throttle(
      callback,
      duration: const Duration(milliseconds: 16),
    );
  }

  /// Frame-rate throttled function with parameter
  static Function throttleFrameWithParam(Function callback) {
    return throttleWithParam(
      callback,
      duration: const Duration(milliseconds: 16),
    );
  }
}

/// Debounced text field widget
///
/// Text field with built-in debounce for onChanged callback.
class DebouncedTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final Duration debounceDuration;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final TextStyle? style;

  const DebouncedTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.decoration,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.style,
  });

  @override
  State<DebouncedTextField> createState() => _DebouncedTextFieldState();
}

class _DebouncedTextFieldState extends State<DebouncedTextField> {
  late TextEditingController _controller;
  Timer? _debounceTimer;
  String _lastValue = '';

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
      _lastValue = widget.initialValue!;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value) {
    _lastValue = value;

    _debounceTimer?.cancel();

    _debounceTimer = Timer(widget.debounceDuration, () {
      if (widget.onChanged != null) {
        widget.onChanged!(_lastValue);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      decoration: widget.decoration,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: widget.obscureText,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      enabled: widget.enabled,
      style: widget.style,
    );
  }
}

/// Throttled gesture detector
///
/// GestureDetector that throttles tap and double-tap callbacks.
class ThrottledGestureDetector extends StatelessWidget {
  final Widget child;
  final GestureTapCallback? onTap;
  final GestureTapCallback? onDoubleTap;
  final Duration throttleDuration;
  final HitTestBehavior behavior;

  const ThrottledGestureDetector({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.throttleDuration = const Duration(milliseconds: 100),
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  Widget build(BuildContext context) {
    final throttledOnTap = onTap != null
        ? DebounceThrottle.throttle(
            () => onTap!(),
            duration: throttleDuration,
          ) as GestureTapCallback?
        : null;

    final throttledOnDoubleTap = onDoubleTap != null
        ? DebounceThrottle.throttle(
            () => onDoubleTap!(),
            duration: throttleDuration,
          ) as GestureTapCallback?
        : null;

    return GestureDetector(
      onTap: throttledOnTap,
      onDoubleTap: throttledOnDoubleTap,
      behavior: behavior,
      child: child,
    );
  }
}

/// Frame-throttled slider
///
/// Slider that only updates value once per frame (16ms).
/// Use for brightness/volume controls to prevent jank.
class FrameThrottledSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final Color? activeColor;
  final Color? inactiveColor;

  const FrameThrottledSlider({
    super.key,
    required this.value,
    this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.label,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<FrameThrottledSlider> createState() => _FrameThrottledSliderState();
}

class _FrameThrottledSliderState extends State<FrameThrottledSlider> {
  void _handleChanged(double value) {
    if (widget.onChanged != null) {
      DebounceThrottle.throttleFrame(() => widget.onChanged!(value));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Slider(
      value: widget.value,
      onChanged: _handleChanged,
      min: widget.min,
      max: widget.max,
      divisions: widget.divisions,
      label: widget.label,
      activeColor: widget.activeColor,
      inactiveColor: widget.inactiveColor,
    );
  }
}

/// Settings autosave utility
///
/// Debounces settings changes with 500ms delay.
/// Use for settings that should save automatically.
class SettingsAutosave {
  Timer? _autosaveTimer;
  final Map<String, dynamic> _pendingChanges = {};
  final Future<void> Function(Map<String, dynamic>) onSave;

  SettingsAutosave({required this.onSave});

  /// Queue a setting change for autosave
  void queueChange(String key, dynamic value) {
    _pendingChanges[key] = value;

    _autosaveTimer?.cancel();

    _autosaveTimer = Timer(const Duration(milliseconds: 500), () {
      if (_pendingChanges.isNotEmpty) {
        final changes = Map<String, dynamic>.from(_pendingChanges);
        _pendingChanges.clear();
        onSave(changes);
      }
    });
  }

  /// Force immediate save
  Future<void> forceSave() async {
    _autosaveTimer?.cancel();

    if (_pendingChanges.isNotEmpty) {
      final changes = Map<String, dynamic>.from(_pendingChanges);
      _pendingChanges.clear();
      await onSave(changes);
    }
  }

  /// Cancel pending autosave
  void cancel() {
    _autosaveTimer?.cancel();
    _pendingChanges.clear();
  }

  /// Get pending changes
  Map<String, dynamic> get pendingChanges =>
      Map<String, dynamic>.from(_pendingChanges);

  /// Clear pending changes without saving
  void clearPending() {
    _pendingChanges.clear();
  }

  void dispose() {
    _autosaveTimer?.cancel();
  }
}
