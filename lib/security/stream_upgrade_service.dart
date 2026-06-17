import 'dart:convert';
import 'dart:io';

import '../models/model.dart';
import 'stream_security_prober.dart';

/// Service for upgrading HTTP streams to HTTPS with manual review fallback.
class StreamUpgradeService {
  StreamUpgradeService._();

  static const _manualReviewFileName = 'http_holdouts_for_review.json';

  /// Upgrades HTTP URLs in a channel list to HTTPS where available.
  ///
  /// Returns a record of (upgradedChannels, failedUpgrades).
  /// - upgradedChannels: Channels with upgraded URLs
  /// - failedUpgrades: List of HTTP URLs that couldn't be upgraded (for manual review)
  static Future<({
    List<ChannelModel> upgradedChannels,
    List<String> failedUpgrades
  })> upgradeChannels(
    List<ChannelModel> channels,
  ) async {
    final upgradedChannels = <ChannelModel>[];
    final failedUpgrades = <String>{};

    // Collect all HTTP URLs from channels
    final httpUrls = <String>[];
    for (final channel in channels) {
      if (channel.streamUrl.startsWith('http://')) {
        httpUrls.add(channel.streamUrl);
      }
      for (final alt in channel.alternateStreams) {
        if (alt.url.startsWith('http://')) {
          httpUrls.add(alt.url);
        }
      }
    }

    // Probe all HTTP URLs for HTTPS availability
    final probeResults = await StreamSecurityProber.probeUrls(httpUrls);

    // Upgrade channels where HTTPS is available
    for (final channel in channels) {
      final upgradedChannel = await _upgradeChannel(channel, probeResults);
      upgradedChannels.add(upgradedChannel);

      // Track failed upgrades
      if (channel.streamUrl.startsWith('http://')) {
        final result = probeResults[channel.streamUrl];
        if (result == null || !result.isHttpsAvailable) {
          failedUpgrades.add(channel.streamUrl);
        }
      }
      for (final alt in channel.alternateStreams) {
        if (alt.url.startsWith('http://')) {
          final result = probeResults[alt.url];
          if (result == null || !result.isHttpsAvailable) {
            failedUpgrades.add(alt.url);
          }
        }
      }
    }

    // Save failed upgrades for manual review
    if (failedUpgrades.isNotEmpty) {
      await _saveFailedUpgrades(failedUpgrades.toList());
    }

    return (
      upgradedChannels: upgradedChannels,
      failedUpgrades: failedUpgrades.toList(),
    );
  }

  /// Upgrades HTTP URLs in M3U playlist content.
  ///
  /// Returns a record of (upgradedM3u, failedUpgrades).
  static Future<({String upgradedM3u, List<String> failedUpgrades})> upgradeM3u(
    String m3uContent,
  ) async {
    final httpUrls = StreamSecurityProber.extractHttpUrlsFromM3u(m3uContent);
    if (httpUrls.isEmpty) {
      return (upgradedM3u: m3uContent, failedUpgrades: <String>[]);
    }

    final upgradeMap = await StreamSecurityProber.upgradeHttpUrls(httpUrls);
    final failedUpgrades = <String>[];

    // Replace URLs in M3U content
    var upgradedContent = m3uContent;
    for (final entry in upgradeMap.entries) {
      final original = entry.key;
      final upgraded = entry.value;
      if (original != upgraded) {
        upgradedContent = upgradedContent.replaceAll(original, upgraded);
      } else {
        failedUpgrades.add(original);
      }
    }

    // Save failed upgrades for manual review
    if (failedUpgrades.isNotEmpty) {
      await _saveFailedUpgrades(failedUpgrades);
    }

    return (upgradedM3u: upgradedContent, failedUpgrades: failedUpgrades);
  }

  /// Upgrades a single channel based on probe results.
  static Future<ChannelModel> _upgradeChannel(
    ChannelModel channel,
    Map<String, StreamProbeResult> probeResults,
  ) async {
    // Upgrade primary stream URL
    String newStreamUrl = channel.streamUrl;
    StreamSecurity newSecurity = channel.streamSecurity;

    if (channel.streamUrl.startsWith('http://')) {
      final result = probeResults[channel.streamUrl];
      if (result != null && result.isHttpsAvailable && result.upgradedUrl != null) {
        newStreamUrl = result.upgradedUrl!;
        newSecurity = StreamSecurity.secure;
      } else {
        newSecurity = StreamSecurity.cleartext;
      }
    } else if (channel.streamUrl.startsWith('https://')) {
      newSecurity = StreamSecurity.secure;
    }

    // Upgrade alternate streams
    final upgradedAlternates = <StreamLink>[];
    for (final alt in channel.alternateStreams) {
      String newAltUrl = alt.url;
      if (alt.url.startsWith('http://')) {
        final result = probeResults[alt.url];
        if (result != null && result.isHttpsAvailable && result.upgradedUrl != null) {
          newAltUrl = result.upgradedUrl!;
        }
      }
      upgradedAlternates.add(StreamLink(
        url: newAltUrl,
        label: alt.label,
        headers: alt.headers,
      ));
    }

    return channel.copyWith(
      streamUrl: newStreamUrl,
      alternateStreams: upgradedAlternates,
      streamSecurity: newSecurity,
    );
  }

  /// Saves failed HTTP upgrades to a JSON file for manual review.
  static Future<void> _saveFailedUpgrades(List<String> failedUrls) async {
    try {
      final directory = await _getDocumentsDirectory();
      final file = File('${directory.path}/$_manualReviewFileName');
      final data = {
        'timestamp': DateTime.now().toIso8601String(),
        'failed_count': failedUrls.length,
        'urls': failedUrls,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (_) {
      // Silent fail - don't block upgrade process
    }
  }

  /// Loads previously saved failed HTTP upgrades.
  static Future<Map<String, dynamic>?> loadFailedUpgrades() async {
    try {
      final directory = await _getDocumentsDirectory();
      final file = File('${directory.path}/$_manualReviewFileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (_) {
      // Silent fail
    }
    return null;
  }

  /// Gets the documents directory for saving failed upgrades.
  static Future<Directory> _getDocumentsDirectory() async {
    // In a real app, use path_provider to get the documents directory
    // For now, use a temporary directory
    return Directory.systemTemp;
  }

  /// Clears the manual review file.
  static Future<void> clearManualReviewFile() async {
    try {
      final directory = await _getDocumentsDirectory();
      final file = File('${directory.path}/$_manualReviewFileName');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Silent fail
    }
  }

  /// Applies proxy URL to HTTP streams that couldn't be upgraded.
  ///
  /// This is a fallback mechanism for unavoidable HTTP streams.
  /// The proxy should be a Cloudflare Worker or similar HTTPS proxy.
  static ChannelModel applyProxyToCleartextStream(
    ChannelModel channel,
    String proxyBaseUrl,
  ) {
    if (channel.inferredStreamSecurity != StreamSecurity.cleartext) {
      return channel;
    }

    // Apply proxy to primary stream URL
    final proxiedUrl = _buildProxiedUrl(channel.streamUrl, proxyBaseUrl);
    StreamSecurity newSecurity = StreamSecurity.proxied;

    // Apply proxy to alternate streams
    final proxiedAlternates = <StreamLink>[];
    for (final alt in channel.alternateStreams) {
      if (alt.url.startsWith('http://')) {
        proxiedAlternates.add(StreamLink(
          url: _buildProxiedUrl(alt.url, proxyBaseUrl),
          label: alt.label,
          headers: alt.headers,
        ));
      } else {
        proxiedAlternates.add(alt);
      }
    }

    return channel.copyWith(
      streamUrl: proxiedUrl,
      alternateStreams: proxiedAlternates,
      streamSecurity: newSecurity,
    );
  }

  /// Builds a proxied URL for an HTTP stream.
  static String _buildProxiedUrl(String originalUrl, String proxyBaseUrl) {
    // Encode the original URL and append it to the proxy base
    // Example: https://proxy.example.com/stream?url=http%3A%2F%2Fexample.com%2Fstream.m3u8
    final encoded = Uri.encodeComponent(originalUrl);
    return '$proxyBaseUrl?url=$encoded';
  }
}
