import '../models/model.dart';

/// Sort news: World Cup → Cricket → Football → rest; prefer items with images.
class NewsPriority {
  NewsPriority._();

  static const _worldCup = [
    'world cup',
    'fifa world',
    'wc 2026',
    'world cup 2026',
    'world cup qualifier',
  ];

  static const _cricket = [
    'cricket',
    'ipl',
    'bpl',
    'psl',
    'ashes',
    't20 world',
    'champions trophy',
    'icc',
  ];

  static int rank(NewsModel n) {
    final blob = '${n.title} ${n.summary} ${n.category}'.toLowerCase();
    if (_worldCup.any(blob.contains)) return 0;
    if (n.category == 'Cricket' || _cricket.any(blob.contains)) return 1;
    if (n.category == 'Football' ||
        blob.contains('soccer') ||
        blob.contains('premier league')) {
      return 2;
    }
    return 3;
  }

  static bool isWorldCup(NewsModel n) => rank(n) == 0;

  static bool isCricket(NewsModel n) => rank(n) == 1;

  static String? priorityLabel(NewsModel n) {
    if (isWorldCup(n)) return 'WORLD CUP';
    if (isCricket(n)) return 'CRICKET';
    return null;
  }

  static List<NewsModel> sort(List<NewsModel> items) {
    final copy = List<NewsModel>.from(items);
    copy.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      final img = (a.imageUrl.isNotEmpty ? 0 : 1).compareTo(
        b.imageUrl.isNotEmpty ? 0 : 1,
      );
      if (img != 0) return img;
      return b.publishedAt.compareTo(a.publishedAt);
    });
    return copy;
  }
}
