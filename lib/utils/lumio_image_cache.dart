import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:lumio_tv/core/performance_tuning.dart';

/// Bounded disk cache — tier-aware so low-RAM devices stay smooth.
CacheManager get lumioImageCache => _lumioImageCacheHolder.instance;

class _LumioImageCacheHolder {
  CacheManager? _manager;

  CacheManager get instance {
    _manager ??= CacheManager(
      Config(
        'lumioImages',
        stalePeriod: const Duration(days: 1),
        maxNrOfCacheObjects: PerformanceTuning.diskImageCacheObjects,
      ),
    );
    return _manager!;
  }

  void reset() => _manager = null;
}

final _lumioImageCacheHolder = _LumioImageCacheHolder();
