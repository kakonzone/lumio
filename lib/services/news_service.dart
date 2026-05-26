import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/model.dart';

/// Sports headlines from ESPN public API (+ BBC Sport RSS fallback).
class NewsService {
  NewsService._();

  static const _ua =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/124.0.0.0';

  static const _espnFeeds = <String, String>{
    'Top Stories': 'https://site.api.espn.com/apis/site/v2/sports/news?limit=20',
    'Cricket':
        'https://site.api.espn.com/apis/site/v2/sports/cricket/news?limit=15',
    'Football':
        'https://site.api.espn.com/apis/site/v2/sports/soccer/news?limit=15',
    'NBA': 'https://site.api.espn.com/apis/site/v2/sports/nba/news?limit=12',
    'NFL': 'https://site.api.espn.com/apis/site/v2/sports/nfl/news?limit=12',
    'Tennis':
        'https://site.api.espn.com/apis/site/v2/sports/tennis/news?limit=10',
  };

  static const _bbcSportRss = 'https://feeds.bbci.co.uk/sport/rss.xml';

  static Future<List<NewsModel>> fetchLatest() async {
    final lists = await Future.wait(_espnFeeds.entries.map(_fetchEspnFeed));
    final seen = <String>{};
    final out = <NewsModel>[];
    for (final list in lists) {
      for (final n in list) {
        if (seen.add(n.id)) out.add(n);
      }
    }
    if (out.length < 8) {
      for (final n in await _fetchBbcSportRss()) {
        if (seen.add(n.id)) out.add(n);
      }
    }
    out.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return out.take(40).toList();
  }

  static Future<List<NewsModel>> _fetchEspnFeed(
    MapEntry<String, String> feed,
  ) async {
    try {
      final res = await http
          .get(Uri.parse(feed.value), headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final articles = data['articles'] as List? ?? [];
      final out = <NewsModel>[];
      for (final raw in articles) {
        if (raw is! Map<String, dynamic>) continue;
        final parsed = _parseEspnArticle(raw, feed.key);
        if (parsed != null) out.add(parsed);
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static NewsModel? _parseEspnArticle(
    Map<String, dynamic> raw,
    String category,
  ) {
    final title = raw['headline'] as String? ?? raw['title'] as String? ?? '';
    if (title.trim().isEmpty) return null;

    final images = raw['images'] as List? ?? [];
    var imageUrl = '';
    for (final img in images) {
      if (img is! Map) continue;
      final url = img['url'] as String? ?? '';
      if (url.isNotEmpty) {
        imageUrl = url;
        break;
      }
    }

    final links = raw['links'] as Map<String, dynamic>? ?? {};
    final web = links['web'] as Map<String, dynamic>? ?? {};
    final href = web['href'] as String? ?? '';

    var summary = raw['description'] as String? ?? '';
    if (summary.isEmpty) {
      summary = raw['summary'] as String? ?? '';
    }
    summary = _stripHtml(summary).trim();
    if (summary.length > 220) {
      summary = '${summary.substring(0, 217)}…';
    }

    return NewsModel(
      id: 'espn_${raw['id'] ?? title.hashCode}',
      title: title.trim(),
      category: category,
      source: 'ESPN',
      imageUrl: imageUrl,
      url: href,
      summary: summary,
      publishedAt: DateTime.tryParse(raw['published'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static Future<List<NewsModel>> _fetchBbcSportRss() async {
    try {
      final res = await http
          .get(Uri.parse(_bbcSportRss), headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      return _parseRssItems(res.body, source: 'BBC Sport', idPrefix: 'bbc');
    } catch (_) {
      return [];
    }
  }

  static List<NewsModel> _parseRssItems(
    String xml, {
    required String source,
    required String idPrefix,
  }) {
    final out = <NewsModel>[];
    final blocks = RegExp(r'<item[^>]*>([\s\S]*?)</item>', caseSensitive: false)
        .allMatches(xml);
    for (final block in blocks) {
      final item = block.group(1) ?? '';
      final title = _rssTag(item, 'title');
      if (title.isEmpty) continue;
      final link = _rssTag(item, 'link');
      final desc = _stripHtml(_rssTag(item, 'description'));
      var summary = desc;
      if (summary.length > 220) summary = '${summary.substring(0, 217)}…';
      final pub = _rssTag(item, 'pubDate');
      out.add(
        NewsModel(
          id: '${idPrefix}_${title.hashCode}',
          title: title,
          category: 'Sports',
          source: source,
          url: link,
          summary: summary,
          publishedAt: _parseRssDate(pub) ?? DateTime.now(),
        ),
      );
      if (out.length >= 15) break;
    }
    return out;
  }

  static String _rssTag(String item, String tag) {
    final cdata = RegExp(
      '<$tag><!\\[CDATA\\[(.*?)\\]\\]></$tag>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(item);
    if (cdata != null) return cdata.group(1)?.trim() ?? '';
    final plain = RegExp(
      '<$tag>(.*?)</$tag>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(item);
    return plain?.group(1)?.trim() ?? '';
  }

  static DateTime? _parseRssDate(String raw) {
    if (raw.isEmpty) return null;
    final direct = DateTime.tryParse(raw);
    if (direct != null) return direct;
    try {
      return HttpDate.parse(raw);
    } catch (_) {
      return null;
    }
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
