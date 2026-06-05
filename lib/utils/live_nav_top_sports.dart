import '../models/model.dart';

/// Curated top row on Live nav — GITUN links + main-app T Sports / BTV.
class LiveNavTopSports {
  LiveNavTopSports._();

  static const _slots = <_Slot>[
    _Slot(
      label: 'Football World Cup 2026',
      keywords: ['football world cup 2026', 'world cup 2026', 'fifa world cup'],
    ),
    _Slot(label: 'Live Sports', keywords: ['live sports']),
    _Slot(label: 'FIFA+', keywords: ['fifa+', 'fifa plus', 'fifa ']),
    _Slot(label: 'Willow HD', keywords: ['willow']),
    _Slot(
      label: 'BeIN Sports 1',
      keywords: ['bein sports 1', 'bein sport 1', 'bein 1', 'beinsport 1'],
    ),
    _Slot(
      label: 'Star Sports 1 HD',
      keywords: ['star sports 1'],
      exclude: ['star sports 2', 'star sports 3', 'select'],
    ),
    _Slot(
      label: 'Sony Sports Ten 3 HD',
      keywords: ['sony sports ten 3', 'sony ten 3', 'ten 3 hd'],
    ),
    _Slot(
      label: 'Star Sports 2 HD Hindi',
      keywords: ['star sports 2', 'hindi'],
      matchAll: true,
    ),
    _Slot(
      label: 'Sony Sports Ten 5',
      keywords: ['sony sports ten 5', 'sony ten 5', 'ten 5'],
    ),
    _Slot(label: 'Caze TV', keywords: ['caze tv', 'caze']),
    _Slot(label: 'Asports HD', keywords: ['asports', 'a sports hd', 'a sports']),
    _Slot(
      label: 'T Sports',
      keywords: ['t sports', 'tsports', 't-sports'],
      mainAppOnly: true,
    ),
    _Slot(
      label: 'BTV',
      keywords: ['btv', 'bangladesh television'],
      mainAppOnly: true,
      exclude: ['btv world', 'btv news'],
    ),
    _Slot(label: 'Caze T', keywords: ['caze t']),
  ];

  static List<ChannelModel> build({
    required List<ChannelModel> mainCatalog,
    required List<ChannelModel> gitun,
  }) {
    final used = <String>{};
    final out = <ChannelModel>[];

    for (final slot in _slots) {
      final picked = _pick(slot, mainCatalog, gitun, used);
      if (picked != null) {
        used.add(_dedupeKey(picked));
        out.add(
          picked.copyWith(
            category: 'Sports',
            isLive: true,
          ),
        );
      }
    }
    return out;
  }

  static bool isPinned(ChannelModel channel, List<ChannelModel> pinned) {
    final key = _dedupeKey(channel);
    return pinned.any((p) => _dedupeKey(p) == key);
  }

  static ChannelModel? _pick(
    _Slot slot,
    List<ChannelModel> main,
    List<ChannelModel> gitun,
    Set<String> used,
  ) {
    final pools = slot.mainAppOnly
        ? [main]
        : [
            gitun,
            main,
          ];

    ChannelModel? best;
    var bestScore = 0;

    for (final pool in pools) {
      for (final ch in pool) {
        if (ch.streamUrl.isEmpty) continue;
        final key = _dedupeKey(ch);
        if (used.contains(key)) continue;
        final score = _score(ch.name, slot);
        if (score > bestScore) {
          bestScore = score;
          best = ch;
        }
      }
      if (best != null && slot.mainAppOnly) break;
      if (best != null && bestScore >= 80) break;
    }

    return bestScore > 0 ? best : null;
  }

  static int _score(String name, _Slot slot) {
    final n = _normalize(name);
    for (final ex in slot.exclude) {
      if (n.contains(_normalize(ex))) return 0;
    }

    if (slot.matchAll) {
      for (final kw in slot.keywords) {
        if (!n.contains(_normalize(kw))) return 0;
      }
      return 90;
    }

    var best = 0;
    for (final kw in slot.keywords) {
      final k = _normalize(kw);
      if (n == k) {
        best = best < 100 ? 100 : best;
      } else if (n.contains(k)) {
        best = best < 70 + k.length ? 70 + k.length.clamp(0, 25) : best;
      }
    }
    return best;
  }

  static String _dedupeKey(ChannelModel ch) =>
      _normalize(ch.name).replaceAll(RegExp(r'\s+'), ' ');

  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[+_|]'), ' ').trim();
}

class _Slot {
  const _Slot({
    required this.label,
    required this.keywords,
    this.matchAll = false,
    this.mainAppOnly = false,
    this.exclude = const [],
  });

  final String label;
  final List<String> keywords;
  final bool matchAll;
  final bool mainAppOnly;
  final List<String> exclude;
}
