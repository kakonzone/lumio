import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../data/mock_data.dart';

Router buildRouter() {
  final router = Router();

  // ── Health ───────────────────────────────────────────────
  router.get('/health', _health);

  // ── Channels ─────────────────────────────────────────────
  // IMPORTANT: static paths MUST be registered before parametric ones.
  // /api/channels/categories must come before /api/channels/<id>
  // or shelf_router will swallow "categories" as an id param.
  router.get('/api/channels/categories', _channelCategories);
  router.get('/api/channels', _channels);
  router.get('/api/channels/<id>', _channelById);

  // ── Matches ──────────────────────────────────────────────
  // Same rule: /api/matches/predictions before /api/matches/<id>
  router.get('/api/matches/predictions', _predictions);
  router.get('/api/matches', _matches);
  router.get('/api/matches/<id>', _matchById);

  // ── News ─────────────────────────────────────────────────
  router.get('/api/news', _news);

  // ── Live dashboard ───────────────────────────────────────
  router.get('/api/live', _live);

  // ── 404 fallback ─────────────────────────────────────────
  router.all('/<ignored|.*>', (Request req) => _notFound('Route not found'));

  return router;
}

// ── Handlers ──────────────────────────────────────────────────────────────

Response _health(Request req) {
  return _json({
    'status': 'ok',
    'app': 'Lumio TV API',
    'version': '1.0.0',
    'timestamp': DateTime.now().toIso8601String(),
  });
}

// GET /api/channels
// Query params: category, country, live=true, q (search)
Response _channels(Request req) {
  var channels = List.of(mockChannels);
  final p = req.url.queryParameters;

  if (p.containsKey('category')) {
    final cat = p['category']!.toLowerCase();
    channels = channels.where((c) => c.category.toLowerCase() == cat).toList();
  }
  if (p.containsKey('country')) {
    final country = p['country']!.toLowerCase();
    channels =
        channels.where((c) => c.country.toLowerCase() == country).toList();
  }
  if (p['live'] == 'true') {
    channels = channels.where((c) => c.isLive).toList();
  }
  if (p.containsKey('q')) {
    final q = p['q']!.toLowerCase();
    channels = channels.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  // Sort: live channels first, then by viewer count descending
  channels.sort((a, b) {
    if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
    return b.viewers.compareTo(a.viewers);
  });

  return _json({
    'channels': channels.map((c) => c.toJson()).toList(),
    'total': channels.length,
  });
}

// GET /api/channels/categories
Response _channelCategories(Request req) {
  final cats = mockChannels.map((c) => c.category).toSet().toList()..sort();
  final result = cats.map((cat) {
    final all = mockChannels.where((c) => c.category == cat).toList();
    final live = all.where((c) => c.isLive).length;
    return {
      'name': cat,
      'total': all.length,
      'live': live,
    };
  }).toList();
  return _json({'categories': result, 'total': result.length});
}

// GET /api/channels/:id
Response _channelById(Request req, String id) {
  final channel = mockChannels.where((c) => c.id == id).firstOrNull;
  if (channel == null) return _notFound('Channel not found');
  return _json(channel.toJson());
}

// GET /api/matches
// Query params: status (live|today|upcoming|finished), sport
Response _matches(Request req) {
  var matches = List.of(mockMatches);
  final p = req.url.queryParameters;

  if (p.containsKey('status')) {
    final s = p['status']!.toLowerCase();
    if (s == 'today') {
      final now = DateTime.now();
      matches = matches.where((m) {
        return m.matchDate.year == now.year &&
            m.matchDate.month == now.month &&
            m.matchDate.day == now.day;
      }).toList();
    } else {
      matches = matches.where((m) => m.status == s).toList();
    }
  }
  if (p.containsKey('sport')) {
    final sport = p['sport']!.toLowerCase();
    matches = matches.where((m) => m.sport.toLowerCase() == sport).toList();
  }

  // Sort: live first, then by matchDate ascending
  matches.sort((a, b) {
    if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
    return a.matchDate.compareTo(b.matchDate);
  });

  return _json({
    'matches': matches.map((m) => m.toJson()).toList(),
    'total': matches.length,
  });
}

// GET /api/matches/predictions
// Returns all non-finished matches sorted by highest combined certainty
// (i.e. how far the win-chance spread is from 50/50)
Response _predictions(Request req) {
  final preds = mockPredictions.map((m) => m.toJson()).toList();
  return _json({'predictions': preds, 'total': preds.length});
}

// GET /api/matches/:id
Response _matchById(Request req, String id) {
  final match = mockMatches.where((m) => m.id == id).firstOrNull;
  if (match == null) return _notFound('Match not found');
  return _json(match.toJson());
}

// GET /api/news
// Query params: category, limit (default 50)
Response _news(Request req) {
  var news = List.of(mockNews);
  final p = req.url.queryParameters;

  if (p.containsKey('category')) {
    final cat = p['category']!.toLowerCase();
    news = news.where((n) => n.category.toLowerCase() == cat).toList();
  }

  // Newest first
  news.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

  // Optional limit
  if (p.containsKey('limit')) {
    final limit = int.tryParse(p['limit']!);
    if (limit != null && limit > 0 && limit < news.length) {
      news = news.sublist(0, limit);
    }
  }

  return _json({
    'news': news.map((n) => n.toJson()).toList(),
    'total': news.length,
  });
}

// GET /api/live
Response _live(Request req) {
  final liveMatches = mockLiveMatches.map((m) => m.toJson()).toList();
  final liveChannels = mockLiveChannels.map((c) => c.toJson()).toList();

  return _json({
    'liveMatches': liveMatches,
    'liveChannels': liveChannels,
    'totalMatches': liveMatches.length,
    'totalChannels': liveChannels.length,
    'updatedAt': DateTime.now().toIso8601String(),
  });
}

// ── Response helpers ──────────────────────────────────────────────────────

Response _json(dynamic data, {int status = 200}) => Response(
      status,
      body: jsonEncode(data),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Response _notFound(String message) => Response.notFound(
      jsonEncode({'error': message}),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
