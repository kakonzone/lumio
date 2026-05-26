/// Rolling fill-rate diagnostics for LevelPlay formats.
class AdHealthMonitor {
  AdHealthMonitor._();
  static final AdHealthMonitor instance = AdHealthMonitor._();

  static const _window = Duration(hours: 1);
  static const _maxAttempts = 200;

  final List<FillAttempt> _attempts = [];

  void recordAttempt({
    required String format,
    required String result,
    int? errorCode,
  }) {
    _attempts.add(
      FillAttempt(
        format: format,
        result: result,
        errorCode: errorCode,
        at: DateTime.now(),
      ),
    );
    _prune();
    while (_attempts.length > _maxAttempts) {
      _attempts.removeAt(0);
    }
  }

  void _prune() {
    final cutoff = DateTime.now().subtract(_window);
    _attempts.removeWhere((a) => a.at.isBefore(cutoff));
  }

  double getFillRate(String format) {
    _prune();
    final relevant = _attempts
        .where(
          (a) =>
              a.format == format &&
              a.result != 'loading',
        )
        .toList(growable: false);
    if (relevant.isEmpty) return 0;
    final filled = relevant.where((a) => a.result == 'filled').length;
    return filled / relevant.length;
  }

  List<FillAttempt> lastAttempts(String format, {int limit = 10}) {
    _prune();
    return _attempts
        .where((a) => a.format == format)
        .toList()
        .reversed
        .take(limit)
        .toList();
  }

  List<FillAttempt> allRecent({int limit = 30}) {
    _prune();
    return _attempts.reversed.take(limit).toList();
  }
}

class FillAttempt {
  FillAttempt({
    required this.format,
    required this.result,
    this.errorCode,
    required this.at,
  });

  final String format;
  final String result;
  final int? errorCode;
  final DateTime at;
}
