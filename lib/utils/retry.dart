import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/result.dart';

/// Centralized retry helper with exponential backoff and jitter.
/// Used for network operations that may fail transiently.
class RetryHelper {
  RetryHelper._();

  /// Execute [fn] with exponential backoff retry logic and jitter.
  ///
  /// [fn]: The function to execute. Returns a Future<T>.
  /// [maxAttempts]: Maximum number of retry attempts (default: 3).
  /// [initialDelayMs]: Initial delay in milliseconds before first retry (default: 1000ms).
  /// [maxDelayMs]: Maximum delay between retries in milliseconds (default: 30000ms).
  /// [backoffMultiplier]: Multiplier for exponential backoff (default: 2.0).
  /// [jitterFactor]: Jitter factor to add randomness (default: 0.1 = 10%).
  /// [onRetry]: Optional callback called before each retry with attempt number and delay.
  /// [retryIf]: Optional predicate to determine if error is retryable (default: retry all).
  ///
  /// Returns the result of [fn] if successful, or throws the last error.
  static Future<T> retry<T>({
    required Future<T> Function() fn,
    int maxAttempts = 3,
    int initialDelayMs = 1000,
    int maxDelayMs = 30000,
    double backoffMultiplier = 2.0,
    double jitterFactor = 0.1,
    void Function(int attempt, int delayMs, Object error)? onRetry,
    bool Function(Object error)? retryIf,
  }) async {
    int attempt = 0;
    int delayMs = initialDelayMs;
    Object? lastError;

    while (true) {
      try {
        return await fn();
      } catch (e, stack) {
        lastError = e;
        attempt++;
        
        // Check if we should retry
        final shouldRetry = retryIf?.call(e) ?? true;
        if (attempt >= maxAttempts || !shouldRetry) {
          if (kDebugMode) {
            debugPrint('[RetryHelper] Max attempts reached or non-retryable error: $e');
          }
          rethrow;
        }

        // Calculate delay with jitter
        final baseDelay = delayMs.toDouble();
        final jitter = (Random().nextDouble() * jitterFactor * baseDelay).toInt();
        final finalDelay = (baseDelay + jitter).toInt().clamp(initialDelayMs, maxDelayMs);

        if (kDebugMode) {
          debugPrint('[RetryHelper] Attempt $attempt/$maxAttempts failed, retrying in ${finalDelay}ms: $e');
        }

        if (onRetry != null) {
          onRetry(attempt, finalDelay, e);
        }

        await Future.delayed(Duration(milliseconds: finalDelay));
        delayMs = (delayMs * backoffMultiplier)
            .toInt()
            .clamp(initialDelayMs, maxDelayMs);
      }
    }
  }

  /// Execute [fn] with Result type instead of throwing exceptions.
  ///
  /// This is the preferred method for network operations as it provides
  /// better error handling and type safety.
  ///
  /// Returns Success<T> on success, Failure<T> on error.
  static Future<Result<T>> retryForResult<T>({
    required Future<T> Function() fn,
    int maxAttempts = 3,
    int initialDelayMs = 1000,
    int maxDelayMs = 30000,
    double backoffMultiplier = 2.0,
    double jitterFactor = 0.1,
    void Function(int attempt, int delayMs, Object error)? onRetry,
    bool Function(Object error)? retryIf,
  }) async {
    try {
      final result = await retry(
        fn: fn,
        maxAttempts: maxAttempts,
        initialDelayMs: initialDelayMs,
        maxDelayMs: maxDelayMs,
        backoffMultiplier: backoffMultiplier,
        jitterFactor: jitterFactor,
        onRetry: onRetry,
        retryIf: retryIf,
      );
      return Success(result);
    } catch (e, stack) {
      return Failure(e, stack);
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

  /// Default retry predicate that retries on common transient errors.
  static bool defaultRetryPredicate(Object error) {
    // Do NOT retry on Appwrite rate limit errors (402)
    final errorStr = error.toString();
    if (errorStr.contains('402') || 
        errorStr.contains('limit_databases_reads_exceeded') ||
        errorStr.contains('limit exceeded')) {
      return false;
    }
    
    // Do NOT retry on DNS failures (permanent network issues)
    if (errorStr.contains('failed host lookup') ||
        errorStr.contains('no address associated with hostname')) {
      return false;
    }
    
    // Retry on network errors
    if (error is HttpError) {
      return error.isServerError || error.isTimeout || error.isNetworkError;
    }
    
    // Retry on timeout errors
    if (error is TimeoutError) {
      return true;
    }
    
    // Retry on socket exceptions
    return errorStr.toLowerCase().contains('socket') ||
           errorStr.toLowerCase().contains('connection') ||
           errorStr.toLowerCase().contains('network') ||
           errorStr.toLowerCase().contains('timeout');
  }
}
