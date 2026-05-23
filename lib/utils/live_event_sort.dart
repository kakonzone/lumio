import '../models/live_event_match.dart';
import '../models/model.dart';

/// Live first, then scheduled by kickoff, then finished.
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
    final ba = _bucket(ma);
    final bb = _bucket(mb);
    if (ba != bb) return ba.compareTo(bb);
    final cmp = ma.matchDate.compareTo(mb.matchDate);
    if (cmp != 0) return cmp;
    return ma.id.compareTo(mb.id);
  }
}
