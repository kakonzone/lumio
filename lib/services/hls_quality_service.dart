import 'package:http/http.dart' as http;

/// Parsed HLS variant from a master playlist.
class HlsVariant {
  final int width;
  final int height;
  final int bandwidth;
  final String url;

  const HlsVariant({
    this.width = 0,
    required this.height,
    required this.bandwidth,
    required this.url,
  });

  /// e.g. `1280 × 720, 2.10 Mbps` from #EXT-X-STREAM-INF.
  String get displayLabel {
    if (width > 0 && height > 0) {
      final mbps = bandwidth > 0 ? bandwidth / 1000000.0 : 0.0;
      final bw =
          mbps > 0 ? ', ${mbps.toStringAsFixed(2)} Mbps' : '';
      return '$width × $height$bw';
    }
    if (height > 0) return '${height}p';
    return 'Stream';
  }

  String get label {
    if (height >= 1080) return '1080p';
    if (height >= 720) return '720p';
    if (height >= 480) return '480p';
    if (height >= 360) return '360p';
    if (height >= 240) return '240p';
    if (height >= 180) return '180p';
    return '${height}p';
  }
}

class HlsQualityService {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  /// Fetches variants from master (or parent) playlist.
  static Future<List<HlsVariant>> fetchVariants(
    String streamUrl, {
    Map<String, String>? headers,
  }) async {
    if (!streamUrl.contains('.m3u8')) return [];

    final httpHeaders = {'User-Agent': _ua, ...?headers};

    for (final url in _candidatePlaylistUrls(streamUrl)) {
      final variants = await _fetchFromUrl(url, httpHeaders);
      if (variants.length > 1) return variants;
    }

    return _fetchFromUrl(streamUrl, httpHeaders);
  }

  static List<String> _candidatePlaylistUrls(String url) {
    final out = <String>{url};
    final uri = Uri.tryParse(url);
    if (uri == null) return out.toList();

    if (uri.pathSegments.length > 1) {
      final parent = uri.pathSegments.sublist(0, uri.pathSegments.length - 1);
      for (final name in [
        'playlist.m3u8',
        'index.m3u8',
        'master.m3u8',
        'chunklist.m3u8',
        'manifest.m3u8',
      ]) {
        out.add(uri.replace(pathSegments: [...parent, name]).toString());
      }
      if (parent.length > 1) {
        final grand = parent.sublist(0, parent.length - 1);
        out.add(
          uri.replace(pathSegments: [...grand, 'playlist.m3u8']).toString(),
        );
      }
    }
    return out.toList();
  }

  static Future<List<HlsVariant>> _fetchFromUrl(
    String url,
    Map<String, String> headers,
  ) async {
    try {
      final res = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return [];
      return _parsePlaylist(res.body, url);
    } catch (_) {
      return [];
    }
  }

  static List<HlsVariant> _parsePlaylist(String body, String baseUrl) {
    if (!body.contains('#EXT-X-STREAM-INF')) return [];

    final lines = body.split('\n');
    final variants = <HlsVariant>[];
    int? pendingWidth;
    int? pendingHeight;
    int pendingBw = 0;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.startsWith('#EXT-X-STREAM-INF')) {
        pendingWidth = null;
        pendingHeight = null;
        pendingBw = 0;

        final resMatch = RegExp(
          r'RESOLUTION=\s*(\d+)\s*x\s*(\d+)',
          caseSensitive: false,
        ).firstMatch(line);
        if (resMatch != null) {
          final w = int.tryParse(resMatch.group(1) ?? '') ?? 0;
          final h = int.tryParse(resMatch.group(2) ?? '') ?? 0;
          if (w > 0) pendingWidth = w;
          if (h > 0) pendingHeight = h;
        }

        final bwMatch =
            RegExp(r'BANDWIDTH=(\d+)', caseSensitive: false).firstMatch(line);
        pendingBw = int.tryParse(bwMatch?.group(1) ?? '') ?? 0;
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        final h = pendingHeight ?? _heightFromBandwidth(pendingBw);
        if (h > 0) {
          variants.add(
            HlsVariant(
              width: pendingWidth ?? 0,
              height: h,
              bandwidth: pendingBw,
              url: _resolveUrl(baseUrl, line),
            ),
          );
        }
        pendingWidth = null;
        pendingHeight = null;
        pendingBw = 0;
      }
    }

    variants.sort((a, b) => b.height.compareTo(a.height));
    final seen = <int>{};
    return variants.where((v) => seen.add(v.height)).toList();
  }

  static int _heightFromBandwidth(int bw) {
    if (bw <= 0) return 0;
    if (bw >= 5000000) return 1080;
    if (bw >= 2500000) return 720;
    if (bw >= 1000000) return 480;
    if (bw >= 500000) return 360;
    if (bw >= 300000) return 240;
    return 180;
  }

  static String _resolveUrl(String base, String relative) {
    if (relative.startsWith('http')) return relative;
    return Uri.parse(base).resolve(relative).toString();
  }

  /// User-selected quality: exact match → URL hint → cap at/below target → lowest rendition.
  static HlsVariant? pickVariantForced(
    List<HlsVariant> variants,
    int targetHeight,
  ) {
    if (variants.isEmpty) return null;

    bool heightMatches(int h) => h > 0 && (h == targetHeight || (h - targetHeight).abs() <= 24);

    final exact = variants.where((v) => heightMatches(v.height)).toList();
    if (exact.isNotEmpty) {
      exact.sort((a, b) => (a.height - targetHeight).abs().compareTo((b.height - targetHeight).abs()));
      return exact.first;
    }

    final urlHints = <String>[
      '${targetHeight}p',
      '_${targetHeight}_',
      '/$targetHeight/',
      'x$targetHeight',
      'live_${targetHeight}p',
    ];
    for (final v in variants) {
      final lower = v.url.toLowerCase();
      if (urlHints.any(lower.contains)) return v;
    }

    final capped = variants.where((v) => v.height > 0 && v.height <= targetHeight).toList()
      ..sort((a, b) => b.height.compareTo(a.height));
    if (capped.isNotEmpty) return capped.first;

    final sorted = [...variants]..sort((a, b) => a.height.compareTo(b.height));
    return sorted.first;
  }

  @Deprecated('Use pickVariantForced')
  static HlsVariant? pickVariantAtMost(
    List<HlsVariant> variants,
    int targetHeight,
  ) =>
      pickVariantForced(variants, targetHeight);

  /// Maps estimated throughput (Mbps) to a target rendition height.
  static int autoTargetHeightForMbps(double mbps, {bool downgrade = false}) {
    var h = 720;
    if (mbps < 0.5) {
      h = 270;
    } else if (mbps < 1.0) {
      h = 360;
    } else if (mbps < 2.0) {
      h = 540;
    } else if (mbps < 5.0) {
      h = 720;
    } else {
      h = 1080;
    }
    if (downgrade) h = _stepDownTier(h);
    return h;
  }

  static int _stepDownTier(int h) {
    const tiers = [180, 270, 360, 480, 540, 720, 1080];
    final idx = tiers.indexWhere((t) => t >= h);
    final i = idx < 0 ? tiers.length - 1 : idx;
    return tiers[i > 0 ? i - 1 : 0];
  }

  /// Auto mode: pick best HLS variant for estimated Mbps.
  static HlsVariant? pickVariantForAuto(
    List<HlsVariant> variants,
    double mbps, {
    bool downgrade = false,
  }) {
    if (variants.isEmpty) return null;
    final targetH = autoTargetHeightForMbps(mbps, downgrade: downgrade);
    return pickVariantForced(variants, targetH);
  }

  /// Warm playlist cache with a lightweight HEAD request.
  static Future<void> prefetchPlaylistHead(
    String streamUrl, {
    Map<String, String>? headers,
  }) async {
    if (!streamUrl.contains('.m3u8')) return;
    try {
      await http
          .head(
            Uri.parse(streamUrl),
            headers: {'User-Agent': _ua, ...?headers},
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }
}
