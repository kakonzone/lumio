import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/models/model.dart';
import 'package:lumio_tv/utils/news_priority.dart';

void main() {
  test('World Cup ranks before cricket', () {
    final wc = NewsModel(
      id: '1',
      title: 'FIFA World Cup 2026 draw',
      category: 'Football',
      source: 'ESPN',
      publishedAt: DateTime.now(),
    );
    final cricket = NewsModel(
      id: '2',
      title: 'IPL final preview',
      category: 'Cricket',
      source: 'ESPN',
      publishedAt: DateTime.now(),
    );
    final sorted = NewsPriority.sort([cricket, wc]);
    expect(sorted.first.title, contains('World Cup'));
  });
}
