import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/model.dart';

class ApiService {
  // ── Base URL (platform-aware) ──────────────────────────
  // Android emulator  → 10.0.2.2  (loopback alias to host machine)
  // iOS simulator     → localhost  (shares host network)
  // Physical device   → set LUMIO_API_HOST env var, or replace with your LAN IP
  static String get _base {
    const envHost = String.fromEnvironment('LUMIO_API_HOST', defaultValue: '');
    if (envHost.isNotEmpty) return 'http://$envHost:8080';
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8080';
    if (kReleaseMode) {
      throw StateError(
        'LUMIO_API_HOST must be set via --dart-define=LUMIO_API_HOST=<host> '
        'in release builds.',
      );
    }
    return 'http://localhost:8080';
  }

  static const Duration _timeout = Duration(seconds: 10);
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      sendTimeout: _timeout,
    ),
  );

  // ── Internal helpers ───────────────────────────────────

  /// GET with timeout. Throws [ApiException] on non-200 or network error.
  static Future<Map<String, dynamic>> _get(Uri uri) async {
    try {
      final res = await _dio.get(uri.toString());
      if (res.statusCode == 200) {
        return res.data as Map<String, dynamic>;
      }
      throw ApiException(
        'Server returned ${res.statusCode}',
        statusCode: res.statusCode,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw ApiException('Request timeout');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw ApiException('No internet connection');
      }
      if (e.type == DioExceptionType.badResponse) {
        throw ApiException(
          'Server returned ${e.response?.statusCode}',
          statusCode: e.response?.statusCode,
        );
      }
      throw ApiException('Could not reach the server');
    } on FormatException {
      throw ApiException('Invalid response format from server');
    }
  }

  // ── Channels ───────────────────────────────────────────

  static Future<List<ChannelModel>> getChannels({
    String? category,
    String? country,
    bool? live,
  }) async {
    try {
      final uri = Uri.parse('$_base/api/channels').replace(
        queryParameters: {
          if (category != null) 'category': category,
          if (country != null) 'country': country,
          if (live == true) 'live': 'true',
        },
      );
      final data = await _get(uri);
      final list = data['channels'] as List? ?? [];
      return list
          .map((c) => ChannelModel.fromJson(c as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      debugPrint('[ApiService.getChannels] $e\n$stack');
      return [];
    }
  }

  static Future<List<ChannelModel>> getLiveChannels() =>
      getChannels(live: true);

  // ── Matches ────────────────────────────────────────────

  static Future<List<MatchModel>> getMatches({
    String? status,
    String? sport,
  }) async {
    try {
      final uri = Uri.parse('$_base/api/matches').replace(
        queryParameters: {
          if (status != null) 'status': status,
          if (sport != null) 'sport': sport,
        },
      );
      final data = await _get(uri);
      final list = data['matches'] as List? ?? [];
      return list
          .map((m) => MatchModel.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      debugPrint('[ApiService.getMatches] $e\n$stack');
      return [];
    }
  }

  static Future<List<MatchModel>> getLiveMatches() =>
      getMatches(status: 'live');

  static Future<List<MatchModel>> getTodayMatches() =>
      getMatches(status: 'today');

  static Future<List<MatchModel>> getUpcomingMatches() =>
      getMatches(status: 'upcoming');

  // ── Predictions ────────────────────────────────────────

  static Future<List<MatchModel>> getPredictions() async {
    try {
      final uri = Uri.parse('$_base/api/matches/predictions');
      final data = await _get(uri);
      final list = data['predictions'] as List? ?? [];
      return list
          .map((m) => MatchModel.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      debugPrint('[ApiService.getPredictions] $e\n$stack');
      return [];
    }
  }

  // ── News ───────────────────────────────────────────────

  static Future<List<NewsModel>> getNews({String? category}) async {
    try {
      final uri = Uri.parse('$_base/api/news').replace(
        queryParameters: {
          if (category != null) 'category': category,
        },
      );
      final data = await _get(uri);
      final list = data['news'] as List? ?? [];
      return list
          .map((n) => NewsModel.fromJson(n as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      debugPrint('[ApiService.getNews] $e\n$stack');
      return [];
    }
  }

  // ── Live dashboard ─────────────────────────────────────

  static Future<Map<String, dynamic>> getLiveData() async {
    try {
      return await _get(Uri.parse('$_base/api/live'));
    } catch (e, stack) {
      debugPrint('[ApiService.getLiveData] $e\n$stack');
      return {};
    }
  }
}

// ── ApiException ───────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => statusCode != null
      ? 'ApiException($statusCode): $message'
      : 'ApiException: $message';
}
