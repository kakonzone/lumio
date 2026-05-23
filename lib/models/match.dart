class MatchModel {
  final String id;
  final String sport;
  final String teamA;
  final String teamB;
  final String scoreA;
  final String scoreB;
  final String status; // 'live' | 'upcoming' | 'finished'
  final String time;
  final String channel;
  final String streamUrl;
  final DateTime matchDate;
  final double winChanceA;
  final double winChanceB;
  final double drawChance;

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
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) => MatchModel(
        id: json['id'] as String? ?? '',
        sport: json['sport'] as String? ?? '',
        teamA: json['teamA'] as String? ?? '',
        teamB: json['teamB'] as String? ?? '',
        scoreA: json['scoreA'] as String? ?? '',
        scoreB: json['scoreB'] as String? ?? '',
        status: json['status'] as String? ?? 'upcoming',
        time: json['time'] as String? ?? '',
        channel: json['channel'] as String? ?? '',
        streamUrl: json['streamUrl'] as String? ?? '',
        matchDate: json['matchDate'] != null
            ? DateTime.tryParse(json['matchDate'] as String) ?? DateTime.now()
            : DateTime.now(),
        winChanceA: (json['winChanceA'] as num?)?.toDouble() ?? 50,
        winChanceB: (json['winChanceB'] as num?)?.toDouble() ?? 50,
        drawChance: (json['drawChance'] as num?)?.toDouble() ?? 0,
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
      };

  bool get isLive => status == 'live';
  bool get isUpcoming => status == 'upcoming';
  bool get isFinished => status == 'finished';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MatchModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
