// lib/models/model.dart
// Single-file model layer. Do NOT also export channel.dart / match.dart / news.dart
// alongside these inline definitions — that causes duplicate class errors.
// Every screen/service imports only this one file.

// ── Header Constants ──────────────────────────────────────────────────────────
// Toffee cookie — toffeelive.com থেকে login করে নিজের cookie নাও
// Browser > F12 > Network > playlist.m3u8 > Request Headers > Cookie
const String toffeeCookie = 'YOUR_TOFFEE_COOKIE_HERE';
const String toffeeUA =
    'Toffee (Linux;Android 14) AndroidXMedia3/1.1.1/64103898/4d2ec9b8c7534adc';
const String mozillaUA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/124.0.0.0 Safari/537.36';

// ─── Stream link (multi-source per channel) ─────────────────────────────────
class StreamLink {
  final String url;
  final String label;
  final Map<String, String> headers;

  const StreamLink({
    required this.url,
    this.label = 'Link',
    this.headers = const {'User-Agent': mozillaUA},
  });

  factory StreamLink.fromJson(Map<String, dynamic> j) => StreamLink(
        url: j['url'] as String? ?? '',
        label: j['label'] as String? ?? 'Link',
        headers: j['headers'] != null
            ? Map<String, String>.from(j['headers'] as Map)
            : const {'User-Agent': mozillaUA},
      );
}

// ─── Channel Model ────────────────────────────────────────────────────────────
class ChannelModel {
  final String id;
  final String name;
  final String category;
  final String country;
  final String streamUrl;
  final String logoUrl;
  final bool isLive;
  final int viewers;
  final String currentShow;
  final Map<String, String> headers;
  final List<StreamLink> alternateStreams;

  const ChannelModel({
    required this.id,
    required this.name,
    required this.category,
    required this.country,
    required this.streamUrl,
    this.logoUrl = '',
    this.isLive = false,
    this.viewers = 0,
    this.currentShow = '',
    this.headers = const {'User-Agent': mozillaUA},
    this.alternateStreams = const [],
  });

  factory ChannelModel.fromJson(Map<String, dynamic> j) => ChannelModel(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        category: j['category'] as String? ?? '',
        country: j['country'] as String? ?? '',
        streamUrl: j['streamUrl'] as String? ?? '',
        logoUrl: j['logoUrl'] as String? ?? '',
        isLive: j['isLive'] as bool? ?? false,
        viewers: j['viewers'] as int? ?? 0,
        currentShow: j['currentShow'] as String? ?? '',
        headers: j['headers'] != null
            ? Map<String, String>.from(j['headers'] as Map)
            : const {'User-Agent': mozillaUA},
        alternateStreams: (j['alternateStreams'] as List? ?? [])
            .map((e) => StreamLink.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Primary + backup links (deduped by URL).
  List<StreamLink> get allStreams {
    final out = <StreamLink>[];
    final seen = <String>{};
    void add(StreamLink link) {
      if (link.url.isEmpty || seen.contains(link.url)) return;
      seen.add(link.url);
      out.add(link);
    }

    add(StreamLink(url: streamUrl, label: 'SD', headers: headers));
    for (final alt in alternateStreams) {
      add(StreamLink(
        url: alt.url,
        label: alt.label,
        headers: alt.headers.isNotEmpty ? alt.headers : headers,
      ));
    }
    return out;
  }

  bool get hasMultipleStreams => allStreams.length > 1;

  bool matchesStreamUrl(String url) =>
      streamUrl == url || alternateStreams.any((l) => l.url == url);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'country': country,
        'streamUrl': streamUrl,
        'logoUrl': logoUrl,
        'isLive': isLive,
        'viewers': viewers,
        'currentShow': currentShow,
        'headers': headers,
        'alternateStreams': alternateStreams.map((e) => {
              'url': e.url,
              'label': e.label,
              'headers': e.headers,
            }).toList(),
      };

  ChannelModel copyWith({
    String? id,
    String? name,
    String? category,
    String? country,
    String? streamUrl,
    String? logoUrl,
    bool? isLive,
    int? viewers,
    String? currentShow,
    Map<String, String>? headers,
    List<StreamLink>? alternateStreams,
  }) =>
      ChannelModel(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        country: country ?? this.country,
        streamUrl: streamUrl ?? this.streamUrl,
        logoUrl: logoUrl ?? this.logoUrl,
        isLive: isLive ?? this.isLive,
        viewers: viewers ?? this.viewers,
        currentShow: currentShow ?? this.currentShow,
        headers: headers ?? this.headers,
        alternateStreams: alternateStreams ?? this.alternateStreams,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ChannelModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ChannelModel(id: $id, name: $name, category: $category, live: $isLive)';

  // ── Computed helpers ───────────────────────────────────────────────────────
  String get formattedViewers {
    if (viewers >= 1000) return '${(viewers / 1000).toStringAsFixed(1)}k';
    return viewers.toString();
  }

  String get categoryIcon {
    switch (category.toLowerCase()) {
      case 'sports':
        return '🏆';
      case 'bangladesh':
        return '🇧🇩';
      case 'india':
        return '🇮🇳';
      case 'pakistan':
        return '🇵🇰';
      case 'english':
        return '🇬🇧';
      case 'hindi':
        return '📺';
      case 'movies':
        return '🎬';
      case 'kdrama':
        return '🇰🇷';
      case 'kids':
        return '🧒';
      case 'entertainment':
        return '🎭';
      default:
        return '📡';
    }
  }
}

// ─── Match Model ──────────────────────────────────────────────────────────────
class MatchModel {
  final String id;
  final String sport;
  final String teamA;
  final String teamB;
  final String scoreA;
  final String scoreB;
  final String status;
  final String time;
  final String channel;
  final String streamUrl;
  final DateTime matchDate;
  final double winChanceA;
  final double winChanceB;
  final double drawChance;
  /// Score provider label: Cricbuzz, ESPN, etc.
  final String scoreSource;
  final String teamALogo;
  final String teamBLogo;

  const MatchModel({
    required this.id,
    required this.sport,
    required this.teamA,
    required this.teamB,
    this.scoreA = '',
    this.scoreB = '',
    required this.status,
    this.time = '',
    this.channel = '',
    this.streamUrl = '',
    required this.matchDate,
    this.winChanceA = 50,
    this.winChanceB = 50,
    this.drawChance = 0,
    this.scoreSource = '',
    this.teamALogo = '',
    this.teamBLogo = '',
  });

  factory MatchModel.fromJson(Map<String, dynamic> j) => MatchModel(
        id: j['id'] as String? ?? '',
        sport: j['sport'] as String? ?? '',
        teamA: j['teamA'] as String? ?? '',
        teamB: j['teamB'] as String? ?? '',
        scoreA: j['scoreA'] as String? ?? '',
        scoreB: j['scoreB'] as String? ?? '',
        status: j['status'] as String? ?? '',
        time: j['time'] as String? ?? '',
        channel: j['channel'] as String? ?? '',
        streamUrl: j['streamUrl'] as String? ?? '',
        matchDate: DateTime.tryParse(j['matchDate'] as String? ?? '') ??
            DateTime.now(),
        winChanceA: (j['winChanceA'] as num? ?? 50).toDouble(),
        winChanceB: (j['winChanceB'] as num? ?? 50).toDouble(),
        drawChance: (j['drawChance'] as num? ?? 0).toDouble(),
        scoreSource: j['scoreSource'] as String? ?? '',
        teamALogo: j['teamALogo'] as String? ?? '',
        teamBLogo: j['teamBLogo'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sport': sport,
        'teamA': teamA,
        'teamB': teamB,
        'scoreA': scoreA,
        'scoreB': scoreB,
        'status': status,
        'time': time,
        'channel': channel,
        'streamUrl': streamUrl,
        'matchDate': matchDate.toIso8601String(),
        'winChanceA': winChanceA,
        'winChanceB': winChanceB,
        'drawChance': drawChance,
        'scoreSource': scoreSource,
        'teamALogo': teamALogo,
        'teamBLogo': teamBLogo,
      };

  MatchModel copyWith({
    String? id,
    String? sport,
    String? teamA,
    String? teamB,
    String? scoreA,
    String? scoreB,
    String? status,
    String? time,
    String? channel,
    String? streamUrl,
    DateTime? matchDate,
    double? winChanceA,
    double? winChanceB,
    double? drawChance,
    String? scoreSource,
    String? teamALogo,
    String? teamBLogo,
  }) =>
      MatchModel(
        id: id ?? this.id,
        sport: sport ?? this.sport,
        teamA: teamA ?? this.teamA,
        teamB: teamB ?? this.teamB,
        scoreA: scoreA ?? this.scoreA,
        scoreB: scoreB ?? this.scoreB,
        status: status ?? this.status,
        time: time ?? this.time,
        channel: channel ?? this.channel,
        streamUrl: streamUrl ?? this.streamUrl,
        matchDate: matchDate ?? this.matchDate,
        winChanceA: winChanceA ?? this.winChanceA,
        winChanceB: winChanceB ?? this.winChanceB,
        drawChance: drawChance ?? this.drawChance,
        scoreSource: scoreSource ?? this.scoreSource,
        teamALogo: teamALogo ?? this.teamALogo,
        teamBLogo: teamBLogo ?? this.teamBLogo,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MatchModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MatchModel(id: $id, $teamA vs $teamB, status: $status)';

  // ── Computed helpers ───────────────────────────────────────────────────────
  bool get isLive => status == 'live';
  bool get isUpcoming => status == 'upcoming';
  bool get isFinished => status == 'finished';

  String get sportEmoji {
    switch (sport.toLowerCase()) {
      case 'cricket':
        return '🏏';
      case 'football':
        return '⚽';
      case 'basketball':
        return '🏀';
      case 'tennis':
        return '🎾';
      case 'formula 1':
        return '🏎️';
      case 'boxing':
        return '🥊';
      case 'hockey':
        return '🏒';
      case 'volleyball':
        return '🏐';
      default:
        return '🏆';
    }
  }
}

// ─── News Model ───────────────────────────────────────────────────────────────
class NewsModel {
  final String id;
  final String title;
  final String category;
  final String source;
  final String imageUrl;
  final String url;
  final DateTime publishedAt;

  const NewsModel({
    required this.id,
    required this.title,
    required this.category,
    required this.source,
    this.imageUrl = '',
    this.url = '',
    required this.publishedAt,
  });

  factory NewsModel.fromJson(Map<String, dynamic> j) => NewsModel(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        category: j['category'] as String? ?? '',
        source: j['source'] as String? ?? '',
        imageUrl: j['imageUrl'] as String? ?? '',
        url: j['url'] as String? ?? '',
        publishedAt: DateTime.tryParse(j['publishedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'source': source,
        'imageUrl': imageUrl,
        'url': url,
        'publishedAt': publishedAt.toIso8601String(),
      };

  NewsModel copyWith({
    String? id,
    String? title,
    String? category,
    String? source,
    String? imageUrl,
    String? url,
    DateTime? publishedAt,
  }) =>
      NewsModel(
        id: id ?? this.id,
        title: title ?? this.title,
        category: category ?? this.category,
        source: source ?? this.source,
        imageUrl: imageUrl ?? this.imageUrl,
        url: url ?? this.url,
        publishedAt: publishedAt ?? this.publishedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NewsModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'NewsModel(id: $id, title: $title, category: $category)';

  // ── Computed helpers ───────────────────────────────────────────────────────
  String get timeAgo {
    final diff = DateTime.now().difference(publishedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String get categoryEmoji {
    switch (category.toLowerCase()) {
      case 'cricket':
        return '🏏';
      case 'football':
        return '⚽';
      case 'basketball':
        return '🏀';
      case 'tennis':
        return '🎾';
      case 'formula 1':
        return '🏎️';
      case 'boxing':
        return '🥊';
      default:
        return '📰';
    }
  }
}
