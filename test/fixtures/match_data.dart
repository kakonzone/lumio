import 'package:lumio_tv/models/model.dart';

/// Sample match data for testing purposes only.
/// This file is NOT imported by production code.
final List<MatchModel> sampleMatchData = [
  MatchModel(
    id: 'm1',
    sport: 'Cricket',
    teamA: 'Bangladesh',
    teamB: 'India',
    scoreA: '187/4',
    scoreB: '162/8',
    status: 'live',
    time: '18.2 Ov',
    channel: 'T Sports',
    streamUrl: '',
    matchDate: DateTime.now(),
    winChanceA: 55,
    winChanceB: 35,
    drawChance: 10,
  ),
  MatchModel(
    id: 'm2',
    sport: 'Football',
    teamA: 'Arsenal',
    teamB: 'Chelsea',
    scoreA: '2',
    scoreB: '1',
    status: 'live',
    time: '67',
    channel: 'Sony Sports',
    streamUrl: '',
    matchDate: DateTime.now(),
    winChanceA: 48,
    winChanceB: 30,
    drawChance: 22,
  ),
];
