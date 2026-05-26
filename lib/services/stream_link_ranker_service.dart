import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/model.dart';
import '../utils/ad_debug_log.dart';

/// Result of probing one stream URL with HTTP HEAD.
class StreamLinkProbe {
  final StreamLink link;
  final bool alive;
  final int responseMs;
  final int originalIndex;

  const StreamLinkProbe({
    required this.link,
    required this.alive,
    required this.responseMs,
    required this.originalIndex,
  });
}

/// Parallel HEAD probes; alive links sorted fastest-first, dead links last.
class StreamLinkRankerService {
  static const _timeout = Duration(seconds: 5);

  /// Probes all [links] in parallel (5s timeout each). Returns reordered list.
  static Future<List<StreamLink>> rankBySpeed(List<StreamLink> links) async {
    if (links.length <= 1) return links;

    final probes = await Future.wait(
      links.asMap().entries.map((e) => _probe(e.key, e.value)),
    );

    final alive = probes.where((p) => p.alive).toList()
      ..sort((a, b) => a.responseMs.compareTo(b.responseMs));
    final dead = probes.where((p) => !p.alive).toList()
      ..sort((a, b) => a.originalIndex.compareTo(b.originalIndex));

    final ranked = [
      ...alive.map((p) => p.link),
      ...dead.map((p) => p.link),
    ];

    // #region agent log
    _debugLog(
      location: 'stream_link_ranker_service.dart:rankBySpeed',
      message: 'links ranked',
      hypothesisId: 'H-rank',
      data: {
        'inputCount': links.length,
        'aliveCount': alive.length,
        'deadCount': dead.length,
        'order': probes
            .map((p) => {
                  'label': p.link.label,
                  'alive': p.alive,
                  'ms': p.responseMs,
                  'orig': p.originalIndex,
                })
            .toList(),
        'rankedLabels': ranked.map((l) => l.label).toList(),
      },
    );
    // #endregion

    return ranked;
  }

  static Future<StreamLinkProbe> _probe(int index, StreamLink link) async {
    final uri = Uri.tryParse(link.url);
    if (uri == null) {
      return StreamLinkProbe(
        link: link,
        alive: false,
        responseMs: _timeout.inMilliseconds,
        originalIndex: index,
      );
    }

    final sw = Stopwatch()..start();
    try {
      final headers = <String, String>{
        'User-Agent': mozillaUA,
        ...link.headers,
      };
      final res = await http.head(uri, headers: headers).timeout(_timeout);
      sw.stop();
      final ok = res.statusCode == 200 || res.statusCode == 206;
      return StreamLinkProbe(
        link: link,
        alive: ok,
        responseMs: sw.elapsedMilliseconds,
        originalIndex: index,
      );
    } catch (_) {
      sw.stop();
      return StreamLinkProbe(
        link: link,
        alive: false,
        responseMs: sw.elapsedMilliseconds,
        originalIndex: index,
      );
    }
  }

  // #region agent log
  static void _debugLog({
    required String location,
    required String message,
    required String hypothesisId,
    Map<String, dynamic>? data,
    String runId = 'pre-fix',
  }) {
    agentDebugLogToFile(
      sessionId: '5c7b93',
      fileName: 'debug-5c7b93.log',
      location: location,
      message: message,
      hypothesisId: hypothesisId,
      data: data,
      runId: runId,
    );
  }
  // #endregion
}
