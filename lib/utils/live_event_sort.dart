import '../models/live_event_match.dart';
import '../models/model.dart';
import 'live_event_priority.dart';

/// Priority tier → live → upcoming → finished → kickoff.
class LiveEventSort {
  static List<LiveEventMatch> sort(List<LiveEventMatch> events) {
    final copy = List<LiveEventMatch>.from(events);
    copy.sort(_compare);
    return copy;
  }

  static int _bucket(MatchModel m) {
    if (m.isLive) return 0;
    if (m.isUpcoming) return 1;
    return 2;
  }

  static int _compare(LiveEventMatch a, LiveEventMatch b) {
    final ma = a.match;
    final mb = b.match;
    final pa = LiveEventPriority.rank(ma);
    final pb = LiveEventPriority.rank(mb);
    if (pa != pb) return pa.compareTo(pb);
    // Cricket before football within the same priority tier.
    final sa = ma.sport.toLowerCase() == 'cricket' ? 0 : 1;
    final sb = mb.sport.toLowerCase() == 'cricket' ? 0 : 1;
    if (sa != sb) return sa.compareTo(sb);
    final ba = _bucket(ma);
    final bb = _bucket(mb);
    if (ba != bb) return ba.compareTo(bb);
    final cmp = ma.matchDate.compareTo(mb.matchDate);
    if (cmp != 0) return cmp;
    return ma.id.compareTo(mb.id);
  }
}
