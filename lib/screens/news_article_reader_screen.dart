import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ads/ad_manager.dart';
import '../ads/adsterra/adsterra_native.dart';
import '../models/model.dart';
import '../theme/app_theme.dart';
import '../widgets/shell_app_bar.dart';

/// In-app article preview with native after paragraph 2 (Week 2).
class NewsArticleReaderScreen extends StatelessWidget {
  const NewsArticleReaderScreen({super.key, required this.article});

  final NewsModel article;

  List<String> get _paragraphs {
    final raw = article.summary.trim();
    if (raw.isEmpty) {
      return [article.title];
    }
    final parts = raw.split(RegExp(r'\n\s*\n'));
    if (parts.length > 1) return parts.where((p) => p.trim().isNotEmpty).toList();
    return [raw];
  }

  Future<void> _openFullArticle() async {
    final uri = Uri.tryParse(article.url.trim());
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final paragraphs = _paragraphs;

    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShellAppBar(
            showBack: true,
            title: article.category,
            subtitle: article.source,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  article.title,
                  style: GF.head(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.txt,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < paragraphs.length; i++) ...[
                  Text(
                    paragraphs[i],
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: context.txt2,
                    ),
                  ),
                  if (i == 1 && AdManager.instance.adsEnabled) ...[
                    const SizedBox(height: 12),
                    const RepaintBoundary(
                      child: AdsterraNativeBanner(
                        placement: 'news_article_inline',
                        height: 100,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else
                    const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: _openFullArticle,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Read full story'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
