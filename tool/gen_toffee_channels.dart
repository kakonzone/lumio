// Run: dart run tool/gen_toffee_channels.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final jsonPath = Platform.script
      .resolve('../assets/data/toffee_channels.json')
      .toFilePath();
  final outPath = Platform.script
      .resolve('../lib/data/toffee_channels_data.dart')
      .toFilePath();
  final list = jsonDecode(File(jsonPath).readAsStringSync()) as List;
  final buf = StringBuffer('''
// GENERATED — do not edit by hand. Run: dart run tool/gen_toffee_channels.dart
import '../models/model.dart';

class ToffeeChannelsData {
  ToffeeChannelsData._();
  static List<ChannelModel> get all => _all;
  static final List<ChannelModel> _all = [
''');

  var i = 0;
  for (final raw in list) {
    final m = raw as Map<String, dynamic>;
    final id = 'toffee_${i++}';
    final name = m['name'] as String;
    final cat = _mapCat(m['category'] as String, name);
    final link = m['link'] as String;
    final logo = m['logo'] as String? ?? '';
    final cookie = m['cookie'] as String;
    final ua = m['user_agent'] as String? ?? 'okhttp/4.11.0';
    buf.writeln('    _t(');
    buf.writeln("      '$id',");
    buf.writeln('      ${_q(name)},');
    buf.writeln('      ${_q(cat)},');
    buf.writeln('      ${_q(link)},');
    buf.writeln('      ${_q(logo)},');
    buf.writeln('      ${_q(cookie)},');
    buf.writeln('      ${_q(ua)},');
    buf.writeln('    ),');
  }
  buf.writeln('  ];');
  buf.writeln('}');
  File(outPath).writeAsStringSync(buf.toString());
  print('Wrote ${list.length} channels to $outPath');
}

String _q(String s) => "r'${s.replaceAll("'", "\\'")}'";

String _mapCat(String raw, String name) {
  final n = name.toLowerCase();
  switch (raw) {
    case 'LIVE':
      if (n.contains('movie')) return 'Movies';
      if (n.contains('drama')) return 'Entertainment';
      return 'Sports';
    case 'News Channel':
      return 'Bangladesh';
    case 'বাংলাদেশী চ্যানেল':
      return 'Bangladesh';
    case 'Sports Channels':
      return 'Sports';
    case 'Kids':
      return 'Kids';
    case 'Entertainment Channels':
      return 'Entertainment';
    case 'Movie Channels':
      return 'Movies';
    case 'Infotainment':
      return 'English';
    default:
      return 'Entertainment';
  }
}
