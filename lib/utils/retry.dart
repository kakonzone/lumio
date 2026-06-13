import 'dart:async';

import 'package:flutter/foundation.dart';

/// Centralized retry helper with exponential backoff.
/// Used for network operations that may fail transiently.
class RetryHelper {
  RetryHelper._();

  /// Execute [fn] with exponential backoff retry logic.
  ///
  /// [fn]: The function to execute. Returns a Future<T>.
  /// [maxAttempts]: Maximum number of retry attempts (default: 3).
  /// [initialDelayMs]: Initial delay in milliseconds before first retry (default: 1000ms).
  /// [maxDelayMs]: Maximum delay between retries in milliseconds (default: 30000ms).
  /// [backoffMultiplier]: Multiplier for exponential backoff (default: 2.0).
  /// [onRetry]: Optional callback called before each retry with attempt number and delay.
  ///
  /// Returns the result of [fn] if successful, or throws the last error.
  static Future<T> retry<T>({
    required Future<T> Function() fn,
    int maxAttempts = 3,
    int initialDelayMs = 1000,
    int maxDelayMs = 30000,
    double backoffMultiplier = 2.0,
    void Function(int attempt, int delayMs)? onRetry,
  }) async {
    int attempt = 0;
    int delayMs = initialDelayMs;

    while (true) {
      try {
        return await fn();
      } catch (e) {
        attempt++;
        if (attempt >= maxAttempts || !kDebugMode) {
          rethrow;
        }

        if (onRetry != null) {
          onRetry(attempt, delayMs);
        }

        await Future.delayed(Duration(milliseconds: delayMs));
        delayMs = (delayMs * backoffMultiplier)
            .toInt()
            .clamp(initialDelayMs, maxDelayMs);
      }
    }
  }

  /// Execute [fn] with a simple delay retry (no exponential backoff).
  ///
  /// [fn]: The function to execute. Returns a Future<T>.
  /// [maxAttempts]: Maximum number of retry attempts (default: 3).
  /// [delayMs]: Fixed delay between retries in milliseconds (default: 1000ms).
  static Future<T> retryWithFixedDelay<T>({
    required Future<T> Function() fn,
    int maxAttempts = 3,
    int delayMs = 1000,
  }) async {
    int attempt = 0;

    while (true) {
      try {
        return await fn();
      } catch (e) {
        attempt++;
        if (attempt >= maxAttempts) {
          rethrow;
        }

        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
  }
}
