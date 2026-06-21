import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:dart_appwrite/models.dart' as aw_models;
import 'package:flutter/foundation.dart';

import '../config/appwrite_config.dart';
import '../core/result.dart';
import '../models/model.dart';
import '../utils/m3u_merge_parser.dart';
import '../utils/retry.dart';
import 'appwrite_channel_mapper.dart';
import 'special_link/special_link_cache.dart';

/// Main app channel catalog via Appwrite Databases (replaces GitHub M3U for home/sports/live).
class AppwriteService {
  AppwriteService._();

  static final AppwriteService instance = AppwriteService._();

  late final Client _client = _buildClient();
  late final Databases _databases = Databases(_client);

  /// Shared Databases client (e.g. [AppwriteAppConfig]).
  Databases get databases => _databases;

  /// Guest/anonymous client — requires Console Read permission for Guests.
  Client _buildClient() => Client()
      .setEndpoint(AppwriteConfig.endpoint)
      .setProject(AppwriteConfig.projectId);

  /// Last fetch failure (e.g. 401 permissions) — shown in [CatalogService] error UI.
  String? lastFetchError;

  /// All channels for [CatalogService] — cached on disk; feeds home / sports / live / categories.
  Future<List<ChannelModel>> fetchChannels({bool forceRefresh = false}) async {
    lastFetchError = null;
    if (!AppwriteConfig.isConfigured) {
      lastFetchError = 'Appwrite project/database not configured.';
      if (kDebugMode) {
        debugPrint('[Appwrite] missing project/database config');
      }
      return const [];
    }

    if (!forceRefresh) {
      final cached = await SpecialLinkCache.instance.readAppCatalogChannels();
      if (cached != null && cached.isNotEmpty) return cached;
    }

    var channels = <ChannelModel>[];
    try {
      channels = await RetryHelper.retry(
        fn: () async {
          final fetched = await _fetchChannelDocuments();
          if (fetched.isEmpty && lastFetchError == null) {
            return await _fetchPlaylistM3u();
          }
          return fetched;
        },
        maxAttempts: 3,
        initialDelayMs: 1000,
        retryIf: RetryHelper.defaultRetryPredicate,
        onRetry: (attempt, delay, error) {
          if (kDebugMode) {
            debugPrint('[Appwrite] Retry attempt $attempt after ${delay}ms: $error');
          }
        },
      );
    } on AppwriteException catch (e) {
      lastFetchError = _friendlyAppwriteError(e);
      if (kDebugMode) {
        debugPrint('[Appwrite] ${e.message} (code=${e.code})');
      }
      // On 402 rate limit, fall back to cached data or empty list
      if (e.code == 402) {
        if (kDebugMode) {
          debugPrint('[Appwrite] Rate limit exceeded, using cached data or bundled fallback');
        }
        final cached = await SpecialLinkCache.instance.readAppCatalogChannels();
        if (cached != null && cached.isNotEmpty) {
          return cached;
        }
      }
    } catch (e) {
      lastFetchError = e.toString();
      if (kDebugMode) {
        debugPrint('[Appwrite] fetch failed: $e');
      }
    }

    if (channels.isNotEmpty) {
      await SpecialLinkCache.instance.writeAppCatalogChannels(channels);
      if (kDebugMode) {
        debugPrint('[Appwrite] loaded ${channels.length} channels');
      }
    }

    return channels;
  }

  static String _friendlyAppwriteError(AppwriteException e) {
    if (e.code == 401) {
      return 'Appwrite channels: permission denied (401). '
          'Console → iptv_main → channels → Settings → Permissions → '
          'Read for Guests (no API key in the app).';
    }
    if (e.code == 402 || e.type == 'limit_databases_reads_exceeded') {
      return 'Appwrite rate limit exceeded. Using cached data or bundled channels.';
    }
    return e.message ?? 'Appwrite error (code=${e.code})';
  }

  Future<List<ChannelModel>> _fetchChannelDocuments() async {
    final merged = <String, ChannelModel>{};
    var offset = 0;
    var firstPageDocCount = 0;
    const parallelPages = 3;

    Future<aw_models.DocumentList> pageAt(int off) => _databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.channelsCollectionId,
          queries: [
            Query.limit(AppwriteConfig.pageSize),
            Query.offset(off),
          ],
        );

    void ingest(aw_models.DocumentList page) {
      for (final doc in page.documents) {
        final ch = AppwriteChannelMapper.fromDocument(doc);
        if (ch == null || ch.streamUrl.isEmpty) continue;
        final key = AppwriteChannelMapper.catalogMergeKey(doc.data, ch.name);
        final existing = merged[key];
        if (existing == null) {
          merged[key] = ch;
        } else {
          merged[key] = AppwriteChannelMapper.mergeRows(existing, ch);
        }
      }
    }

    while (true) {
      final offsets = List.generate(
        parallelPages,
        (i) => offset + i * AppwriteConfig.pageSize,
      );
      final pages = await Future.wait(offsets.map(pageAt));

      for (var i = 0; i < pages.length; i++) {
        final page = pages[i];
        if (offset == 0 && i == 0) {
          firstPageDocCount = page.documents.length;
        }
        ingest(page);
        if (page.documents.isEmpty ||
            page.documents.length < AppwriteConfig.pageSize) {
          return _finishChannelFetch(
            merged,
            firstPageDocCount: firstPageDocCount,
            offset: offset,
          );
        }
      }
      offset += parallelPages * AppwriteConfig.pageSize;
    }
  }

  List<ChannelModel> _finishChannelFetch(
    Map<String, ChannelModel> merged, {
    required int firstPageDocCount,
    required int offset,
  }) {
    if (merged.isEmpty && offset == 0 && firstPageDocCount > 0) {
      lastFetchError =
          'Appwrite returned $firstPageDocCount rows but none had a valid name/URL. '
          'Check stream_url / streamUrl on each channel document.';
    }
    return merged.values.toList();
  }

  Future<List<ChannelModel>> _fetchPlaylistM3u() async {
    try {
      final doc = await _databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.playlistCollectionId,
        documentId: AppwriteConfig.mainPlaylistDocumentId,
      );
      final body = AppwriteChannelMapper.playlistBody(doc.data);
      if (body == null || body.trim().isEmpty) return const [];

      final result = await compute(parseM3uAppwriteIsolate, body);
      if (result case Success(value: final channels)) {
        return channels;
      } else if (result case Failure(error: final error)) {
        lastFetchError ??= 'Failed to parse playlist: ${error.toString()}';
        if (kDebugMode) {
          debugPrint('[Appwrite] Playlist parse error: ${error.toString()}');
        }
        return const [];
      }
      return const [];
    } on AppwriteException catch (e) {
      lastFetchError ??= _friendlyAppwriteError(e);
      if (kDebugMode) {
        debugPrint('[Appwrite] playlist doc: ${e.message}');
      }
      return const [];
    }
  }
}
