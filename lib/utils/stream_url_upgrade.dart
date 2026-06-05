/// Normalizes playback URLs (HTTP→HTTPS) for Android cleartext policy.
class StreamUrlUpgrade {
  StreamUrlUpgrade._();

  /// Tries HTTPS when the host is known to support TLS; otherwise keeps HTTP.
  static String preferHttps(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return trimmed;
    if (uri.scheme.toLowerCase() != 'http') return trimmed;

    // Many IPTV origins are HTTP-only; upgrading blindly breaks playback.
    if (_httpOnlyHosts.contains(uri.host.toLowerCase())) {
      return trimmed;
    }

    return uri.replace(scheme: 'https').toString();
  }

  /// Blocked navigation targets for ad WebViews.
  static bool isBlockedNavigationUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return true;

    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'javascript' ||
        scheme == 'intent' ||
        scheme == 'file' ||
        scheme == 'content') {
      return true;
    }
    if (uri.path.toLowerCase().endsWith('.apk')) return true;
    return false;
  }

  /// Hosts that commonly break when forced to HTTPS (curated from field tests).
  static const _httpOnlyHosts = <String>{
    '103.180.212.191',
    '202.70.146.135',
    '115.187.41.216',
    '198.195.239.50',
    'live-stream.amarbanglatv.in',
  };
}
