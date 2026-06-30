import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../core/result.dart';
import '../screens/generic_error_screen.dart';

/// Error boundary widget that catches Flutter errors and displays a user-friendly error UI.
///
/// Wrap your entire app or specific sections with this widget to handle errors gracefully.
///
/// ```dart
/// ErrorBoundary(
///   child: MyWidget(),
///   onError: (error, stack) {
///     // Log to crashlytics, analytics, etc.
///   },
/// )
/// ```
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final void Function(Object error, StackTrace stack)? onError;
  final Widget Function(Object error, StackTrace stack)? errorBuilder;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.onError,
    this.errorBuilder,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stack;
  FlutterExceptionHandler? _previousErrorHandler;

  @override
  void initState() {
    super.initState();
    _previousErrorHandler = FlutterError.onError;
    FlutterError.onError = _handleFlutterError;
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    _previousErrorHandler?.call(details);

    widget.onError?.call(
      details.exception,
      details.stack ?? StackTrace.empty,
    );

    if (!mounted) return;

    // Never setState synchronously inside FlutterError.onError — that corrupts
    // the element tree and triggers _OverlayEntryWidget / _dependents failures.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _error = details.exception;
        _stack = details.stack;
      });
    });
  }

  @override
  void dispose() {
    if (FlutterError.onError == _handleFlutterError) {
      FlutterError.onError = _previousErrorHandler;
    }
    super.dispose();
  }

  void _retry() {
    setState(() {
      _error = null;
      _stack = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(_error!, _stack!);
      }

      return GenericErrorScreen(
        title: 'Something went wrong',
        message: 'An unexpected error occurred. Please try again.',
        details: kDebugMode ? _error.toString() : null,
        onRetry: _retry,
      );
    }

    return widget.child;
  }
}

/// Network error boundary specifically for network operations.
///
/// Provides retry functionality for network errors.
class NetworkErrorBoundary extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onRetry;
  final String? customErrorMessage;

  const NetworkErrorBoundary({
    super.key,
    required this.child,
    this.onRetry,
    this.customErrorMessage,
  });

  @override
  State<NetworkErrorBoundary> createState() => _NetworkErrorBoundaryState();
}

class _NetworkErrorBoundaryState extends State<NetworkErrorBoundary> {
  NetworkError? _error;

  void _retry() async {
    setState(() {
      _error = null;
    });

    if (widget.onRetry != null) {
      await widget.onRetry!();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return GenericErrorScreen(
        title: 'Network Error',
        message: widget.customErrorMessage ??
            'Unable to connect to the server. Please check your internet connection.',
        details: kDebugMode ? _error.toString() : null,
        onRetry: widget.onRetry != null ? _retry : null,
      );
    }

    return widget.child;
  }
}
