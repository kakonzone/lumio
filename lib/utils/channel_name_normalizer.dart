/// Cleans M3U / GitHub playlist channel titles for display in the app.
class ChannelNameNormalizer {
  ChannelNameNormalizer._();

  static final _urlInName = RegExp(
    r'https?:?//.*$|rtmps?://.*$|rtsp://.*$',
    caseSensitive: false,
  );

  static final _gluedUrl = RegExp(
    r'https?:?//',
    caseSensitive: false,
  );

  static final _exactNames = <String, String>{
    'tsports': 'T Sports',
    't sports': 'T Sports',
    't-sports': 'T Sports',
    't sports hd': 'T Sports HD',
    'tsports hd': 'T Sports HD',
    'btv': 'BTV',
    'b tv': 'BTV',
    'btv hd': 'BTV HD',
    'bangladesh television': 'BTV',
    'gazi tv': 'Gazi TV',
    'gazi': 'Gazi TV',
    'nagorik tv': 'Nagorik TV',
    'nagrik tv': 'Nagorik TV',
    'channel 9': 'Channel 9',
    'channel9': 'Channel 9',
    'channel i': 'Channel I',
    'channel 24': 'Channel 24',
    'somoy tv': 'Somoy TV',
    'jamuna tv': 'Jamuna TV',
    'rtv': 'RTV',
    'deepto tv': 'Deepto TV',
    'maasranga tv': 'Maasranga TV',
    'independent tv': 'Independent TV',
    'atn bangla': 'ATN Bangla',
    'atn news': 'ATN News',
    'boishakhi tv': 'Boishakhi TV',
    'ntv': 'NTV',
    'star sports 1': 'Star Sports 1 HD',
    'star sports 1 hd': 'Star Sports 1 HD',
    'star sports 2': 'Star Sports 2 HD',
    'star sports 2 hd': 'Star Sports 2 HD',
    'star sports 2 hindi': 'Star Sports 2 HD Hindi',
    'sony sports ten 1': 'Sony Sports Ten 1 HD',
    'sony ten 1': 'Sony Sports Ten 1 HD',
    'sony sports ten 3': 'Sony Sports Ten 3 HD',
    'sony ten 3': 'Sony Sports Ten 3 HD',
    'sony sports ten 5': 'Sony Sports Ten 5 HD',
    'sony ten 5': 'Sony Sports Ten 5 HD',
    'willow': 'Willow HD',
    'willow hd': 'Willow HD',
    'willow tv': 'Willow HD',
    'bein sports 1': 'beIN Sports 1',
    'bein sport 1': 'beIN Sports 1',
    'bein 1': 'beIN Sports 1',
    'fifa+': 'FIFA+',
    'fifa plus': 'FIFA+',
    'ptv sports': 'PTV Sports',
    'geo super': 'Geo Super',
    'a sports': 'A Sports HD',
    'asports': 'A Sports HD',
    'asports hd': 'A Sports HD',
    'caze tv': 'Caze TV',
    'caze t': 'Caze T',
    'toffee': 'Toffee',
    'toffee sports': 'Toffee Sports',
  };

  /// Display-ready channel name.
  static String clean(String raw, {String? tvgName}) {
    var name = _decodeHtml(raw.trim());

    if (name.isEmpty && (tvgName?.trim().isNotEmpty ?? false)) {
      name = _decodeHtml(tvgName?.trim() ?? '');
    }

    name = name.replaceAll(_urlInName, '').trim();
    final glued = _gluedUrl.firstMatch(name);
    if (glued != null) {
      name = name.substring(0, glued.start).trim();
    }

    name = name.replaceAll(RegExp(r'\.m3u8\s*$', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    name = name.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    if (_looksBroken(name) && (tvgName?.trim().isNotEmpty ?? false)) {
      name = _decodeHtml(tvgName?.trim() ?? '');
      name = name.replaceAll(_urlInName, '').trim();
    }

    if (name.isEmpty) return 'Channel';

    return _canonicalize(name);
  }

  static bool _looksBroken(String name) {
    if (name.isEmpty) return true;
    if (name.contains('://')) return true;
    if (name.toLowerCase().contains('.m3u8')) return true;
    if (_gluedUrl.hasMatch(name)) return true;
    if (name.length < 2) return true;
    return false;
  }

  static String _canonicalize(String name) {
    final key = name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final exact = _exactNames[key];
    if (exact != null) return exact;

    if (RegExp(r'^t\s*sports?(\s+hd)?$', caseSensitive: false).hasMatch(key)) {
      return key.contains('hd') ? 'T Sports HD' : 'T Sports';
    }
    if (RegExp(r'^btv(\s+hd)?$', caseSensitive: false).hasMatch(key)) {
      return key.contains('hd') ? 'BTV HD' : 'BTV';
    }
    if (RegExp(r'^star\s+sports\s+(\d+)', caseSensitive: false).hasMatch(key)) {
      final m = RegExp(r'^star\s+sports\s+(\d+)', caseSensitive: false)
          .firstMatch(key)!;
      final n = m.group(1)!;
      if (key.contains('hindi')) return 'Star Sports $n HD Hindi';
      return 'Star Sports $n HD';
    }
    if (RegExp(r'^sony\s+(sports\s+)?ten\s+\d+', caseSensitive: false)
        .hasMatch(key)) {
      final m = RegExp(
        r'^sony\s+(?:sports\s+)?ten\s+(\d+)(\s+hd)?',
        caseSensitive: false,
      ).firstMatch(key);
      if (m != null) {
        final n = m.group(1)!;
        return m.group(2) != null
            ? 'Sony Sports Ten $n HD'
            : 'Sony Sports Ten $n';
      }
    }
    if (key.contains('bein') || key.contains('bien')) {
      final m = RegExp(r'(\d+)').firstMatch(key);
      if (m != null) return 'beIN Sports ${m.group(1)}';
      return 'beIN Sports';
    }
    if (key.contains('willow')) return 'Willow HD';

    return _titleCase(name);
  }

  static String _decodeHtml(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&#38;', '&')
      .replaceAll('&quot;', '"');

  static String _titleCase(String input) {
    if (input.isEmpty) return input;
    final words = input.split(RegExp(r'\s+'));
    return words.map((w) {
      if (w.isEmpty) return w;
      final lower = w.toLowerCase();
      if (lower == 'hd' || lower == 'fhd' || lower == '4k' || lower == 'tv') {
        return lower == 'tv' ? 'TV' : lower.toUpperCase();
      }
      if (lower == 'btv') return 'BTV';
      if (lower.startsWith('tsport')) return 'T Sports';
      return w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }
}
