import '../models/model.dart';
import 'stream_token_service.dart';

/// Resolves playback URLs for protected channels before opening the player.
class ChannelResolver {
  ChannelResolver._();
  static final ChannelResolver instance = ChannelResolver._();

  static bool requiresSignedToken(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.userInfo.isNotEmpty) return true;
    return uri.host.toLowerCase().contains('starshare.net');
  }

  /// Returns signed URL when token API succeeds; otherwise falls back to [embeddedUrl].
  ///
  /// [tokenTimeout] keeps channel taps responsive (player can retry token later).
  Future<ChannelPlaybackResolution> resolveForPlayback({
    required ChannelModel channel,
    required String embeddedUrl,
    Duration tokenTimeout = const Duration(seconds: 2),
  }) async {
    if (!requiresSignedToken(embeddedUrl)) {
      return ChannelPlaybackResolution(
        url: embeddedUrl,
        usedToken: false,
        tokenUnavailable: false,
      );
    }

    final channelId = channel.id.isNotEmpty ? channel.id : channel.name;
    String? signedUrl;
    try {
      signedUrl = await StreamTokenService.instance
          .fetchToken(channelId, originalUrl: embeddedUrl)
          .timeout(tokenTimeout);
    } catch (_) {
      signedUrl = null;
    }
    if (signedUrl != null && signedUrl.isNotEmpty) {
      return ChannelPlaybackResolution(
        url: signedUrl,
        usedToken: true,
        tokenUnavailable: false,
      );
    }

    return ChannelPlaybackResolution(
      url: embeddedUrl,
      usedToken: false,
      tokenUnavailable: false,
    );
  }
}

class ChannelPlaybackResolution {
  const ChannelPlaybackResolution({
    required this.url,
    required this.usedToken,
    required this.tokenUnavailable,
    this.expiresInSeconds,
  });

  final String url;
  final bool usedToken;
  final bool tokenUnavailable;
  final int? expiresInSeconds;
}
