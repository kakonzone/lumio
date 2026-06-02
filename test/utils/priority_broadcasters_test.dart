import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/models/model.dart';
import 'package:lumio_tv/utils/priority_broadcasters.dart';

void main() {
  const base = ChannelModel(
    id: 'x',
    name: 'x',
    category: 'Sports',
    country: 'International',
    streamUrl: 'https://example.com/s.m3u8',
  );

  test('sort order: FIFA, Sony, T Sports, beIN, then others', () {
    final list = [
      base.copyWith(id: '4', name: 'Random Stream 99'),
      base.copyWith(id: '3', name: 'beIN Sports 1'),
      base.copyWith(id: '2', name: 'T Sports HD'),
      base.copyWith(id: '1', name: 'Sony Sports Ten 1'),
      base.copyWith(id: '0', name: 'FIFA World Cup Live'),
    ];
    final sorted = PriorityBroadcasters.sort(list);
    expect(sorted.map((c) => c.id).toList(), ['0', '1', '2', '3', '4']);
  });
}
