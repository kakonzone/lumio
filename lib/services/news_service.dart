import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/model.dart';

/// Latest sports headlines for News + Home screens.
class NewsService {
  static const _ua =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/124.0.0.0';

  static const _feeds = <String, String>{
    'Football': 'https://site.api.espn.com/apis/site/v2/sports/soccer/news?limit=15',
    'Cricket':
        'https://site.api.espn.com/apis/site/v2/sports/cricket/news?limit=15',
    'Sports': 'https://site.api.espn.com/apis/site/v2/sports/news?limit=15',
  };

  static Future<List<NewsModel>> fetchLatest() async {
    final lists = await Future.wait(_feeds.entries.map(_fetchFeed));
    final seen = <String>{};
    final out = <NewsModel>[];
    for (final list in lists) {
      for (final n in list) {
        if (seen.add(n.id)) out.add(n);
      }
    }
    out.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return out.take(30).toList();
  }

  static Future<List<NewsModel>> _fetchFeed(MapEntry<String, String> feed) async {
    try {
      final res = await http
          .get(Uri.parse(feed.value), headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final articles = data['articles'] as List? ?? [];
      final out = <NewsModel>[];
      for (final raw in articles) {
        if (raw is! Map<String, dynamic>) continue;
        final title = raw['headline'] as String? ?? raw['title'] as String? ?? '';
        if (title.isEmpty) continue;
        final images = raw['images'] as List? ?? [];
        String imageUrl = '';
        if (images.isNotEmpty && images.first is Map) {
          imageUrl = (images.first as Map)['url'] as String? ?? '';
        }
        final links = raw['links'] as Map<String, dynamic>? ?? {};
        final web = links['web'] as Map<String, dynamic>? ?? {};
        out.add(NewsModel(
          id: 'espn_${raw['id'] ?? title.hashCode}',
          title: title,
          category: feed.key,
          source: 'ESPN',
          imageUrl: imageUrl,
          url: web['href'] as String? ?? '',
          publishedAt: DateTime.tryParse(raw['published'] as String? ?? '') ??
              DateTime.now(),
        ));
      }
      return out;
    } catch (_) {
      return [];
    }
  }
}
