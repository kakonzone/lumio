/// Converts GitHub blob URLs to raw.githubusercontent.com for direct fetch.
class GithubRawUrl {
  GithubRawUrl._();

  static String resolve(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;

    if (uri.host == 'raw.githubusercontent.com') return trimmed;

    if (uri.host == 'github.com') {
      final parts = uri.pathSegments.where((p) => p.isNotEmpty).toList();
      final blobIdx = parts.indexOf('blob');
      if (blobIdx >= 2 && blobIdx + 1 < parts.length) {
        final owner = parts[0];
        final repo = parts[1];
        final branch = parts[blobIdx + 1];
        final filePath = parts.sublist(blobIdx + 2).join('/');
        return 'https://raw.githubusercontent.com/$owner/$repo/$branch/$filePath';
      }
    }

    return trimmed;
  }
}
