/// Bangladesh Standard Time helpers (UTC+6, no DST).
class BdtTime {
  static const _offset = Duration(hours: 6);

  static DateTime now() => DateTime.now().toUtc().add(_offset);

  static DateTime fromUtc(DateTime utc) => utc.toUtc().add(_offset);

  /// Kickoff instant in UTC for countdown math.
  static DateTime kickoffUtc(DateTime matchDate) =>
      matchDate.isUtc ? matchDate : matchDate.toUtc();

  static Duration untilKickoff(DateTime matchDate) {
    final target = kickoffUtc(matchDate);
    return target.difference(DateTime.now().toUtc());
  }

  /// Countdown until kickoff (English) — beside start time on event cards.
  static String formatCountdown(Duration remaining) {
    if (remaining.isNegative || remaining.inSeconds <= 0) return '00:00:00';
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    final s = remaining.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Bengali day-part + 12h clock, e.g. `সন্ধ্যা 6:00pm`, `ভোর 3:00am`.
  static String formatStartTimeBn(DateTime matchDate) {
    final bdt = fromUtc(kickoffUtc(matchDate));
    return '${_bengaliDayPart(bdt.hour)} ${_format12h(bdt.hour, bdt.minute)}';
  }

  /// 12h clock only, e.g. `6:00 PM` (compact, center of event card).
  static String formatClock12h(DateTime matchDate) {
    final bdt = fromUtc(kickoffUtc(matchDate));
    return _format12h(bdt.hour, bdt.minute).toUpperCase();
  }

  /// Live countdown line for event card footer (updates every second).
  static String formatCountdownLabel(DateTime matchDate) {
    final remaining = untilKickoff(matchDate);
    if (remaining.isNegative || remaining.inSeconds <= 0) {
      return 'Starting soon';
    }
    return 'Starts in ${formatCountdown(remaining)}';
  }

  /// Static schedule subtitle: `Today 8:00 PM`, `Tomorrow 6:30 PM`, etc.
  static String formatScheduleSubtitle(DateTime matchDate) {
    final nowBdt = now();
    final kickoffBdt = fromUtc(kickoffUtc(matchDate));
    final today = DateTime(nowBdt.year, nowBdt.month, nowBdt.day);
    final kickDay =
        DateTime(kickoffBdt.year, kickoffBdt.month, kickoffBdt.day);
    final dayDiff = kickDay.difference(today).inDays;

    if (dayDiff == 0) return 'Today ${formatClock12h(matchDate)}';
    if (dayDiff == 1) return 'Tomorrow ${formatClock12h(matchDate)}';
    if (dayDiff > 1 && dayDiff < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[kickoffBdt.weekday - 1]} ${formatClock12h(matchDate)}';
    }
    return formatClock12h(matchDate);
  }

  @Deprecated('Use formatCountdownLabel + formatScheduleSubtitle')
  static String formatEventCardFooter(DateTime matchDate) =>
      formatCountdownLabel(matchDate);

  /// ভোর 3–6, সকাল 6–12, দুপুর 12–3, বিকাল 3–6, সন্ধ্যা 6–9, রাত 9–3.
  static String _bengaliDayPart(int hour24) {
    if (hour24 >= 3 && hour24 < 6) return 'ভোর';
    if (hour24 >= 6 && hour24 < 12) return 'সকাল';
    if (hour24 >= 12 && hour24 < 15) return 'দুপুর';
    if (hour24 >= 15 && hour24 < 18) return 'বিকাল';
    if (hour24 >= 18 && hour24 < 21) return 'সন্ধ্যা';
    return 'রাত';
  }

  static String _format12h(int hour24, int minute) {
    final isPm = hour24 >= 12;
    var h = hour24 % 12;
    if (h == 0) h = 12;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m${isPm ? 'pm' : 'am'}';
  }
}
