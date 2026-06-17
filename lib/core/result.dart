/// Result type for error handling across the network layer.
///
/// Use this pattern instead of throwing exceptions for recoverable errors:
/// ```dart
/// final result = await someOperation();
/// if (result case Success(value: final data)) {
///   // Handle success
/// } else if (result case Failure(error: final error)) {
///   // Handle error
/// }
/// ```

/// Base class for Result type
sealed class Result<T> {
  const Result();
}

/// Success case containing the value
class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

/// Failure case containing the error
class Failure<T> extends Result<T> {
  final Object error;
  final StackTrace? stackTrace;
  
  const Failure(this.error, [this.stackTrace]);
  
  /// Get error message
  String get errorMessage => error.toString();
  
  @override
  String toString() => error.toString();
  
  /// Check if error is of specific type
  bool isError<E>() => error is E;
  
  /// Get error as specific type
  E? asError<E>() => error as E?;
}

/// Network-specific errors
sealed class NetworkError implements Exception {
  const NetworkError();
}

/// Parse error for M3U parsing failures
class ParseError extends NetworkError {
  final String message;
  final String? content;
  
  const ParseError(this.message, [this.content]);
  
  @override
  String toString() => 'ParseError: $message';
}

/// HTTP request error
class HttpError extends NetworkError {
  final String message;
  final int? statusCode;
  final String? responseBody;
  
  const HttpError(this.message, {this.statusCode, this.responseBody});
  
  @override
  String toString() => 'HttpError($statusCode): $message';
  
  /// Get error message
  String get errorMessage => message;
  
  /// Check if this is a client error (4xx)
  bool get isClientError => statusCode != null && statusCode! >= 400 && statusCode! < 500;
  
  /// Check if this is a server error (5xx)
  bool get isServerError => statusCode != null && statusCode! >= 500 && statusCode! < 600;
  
  /// Check if this is a timeout error
  bool get isTimeout => statusCode == null || message.toLowerCase().contains('timeout');
  
  /// Check if this is a network connectivity error
  bool get isNetworkError => statusCode == null && 
      (message.toLowerCase().contains('network') || 
       message.toLowerCase().contains('connection') ||
       message.toLowerCase().contains('internet'));
}

/// Timeout error
class TimeoutError extends NetworkError {
  final String message;
  final Duration? timeout;
  
  const TimeoutError(this.message, {this.timeout});
  
  @override
  String toString() => 'TimeoutError(${timeout?.inSeconds}s): $message';
  
  /// Get error message
  String get errorMessage => message;
  
  /// Check if this is a network-related timeout
  bool get isNetworkTimeout => message.toLowerCase().contains('network');
}

/// Validation error
class ValidationError extends NetworkError {
  final String message;
  final String? field;
  
  const ValidationError(this.message, {this.field});
  
  @override
  String toString() => field != null ? 'ValidationError($field): $message' : 'ValidationError: $message';
  
  /// Get error message
  String get errorMessage => message;
}
