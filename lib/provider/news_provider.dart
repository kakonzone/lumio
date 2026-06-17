import 'package:flutter/foundation.dart';

import '../models/model.dart';
import '../services/news_service.dart';
import '../../utils/app_logger.dart';

/// News provider.
/// 
/// Handles latest news articles and loading state.
/// Extracted from AppProvider for granular updates.
class NewsProvider extends ChangeNotifier {
  static const _loggerName = 'NewsProvider';
  
  List<NewsModel> _news = [];
  bool _newsLoading = false;
  String? _newsError;

  List<NewsModel> get news => _news;
  bool get newsLoading => _newsLoading;
  String? get newsError => _newsError;
  bool get hasNewsError => _newsError != null;
  bool get hasNews => _news.isNotEmpty;

  NewsProvider();

  /// Load latest news articles.
  Future<void> loadNews() async {
    _newsLoading = true;
    _newsError = null;
    notifyListeners();
    
    AppLogger.info('Loading news...', subsystem: _loggerName);

    try {
      final fetched = await NewsService.fetchLatest();
      _news = fetched;
      AppLogger.info('Loaded ${fetched.length} news articles', subsystem: _loggerName);
    } catch (e, st) {
      _newsError = e.toString();
      _news = const []; // Empty on error - no fake news
      AppLogger.severe('Failed to load news', subsystem: _loggerName, error: e, stackTrace: st);
    } finally {
      _newsLoading = false;
      notifyListeners();
    }
  }

  /// Clear news data.
  void clear() {
    _news = [];
    _newsError = null;
    notifyListeners();
    AppLogger.info('Cleared news', subsystem: _loggerName);
  }
}
