import 'dart:async';
import 'package:flutter/material.dart';
import '../models/model.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/colors.dart';
import '../utils/bdt_time.dart';
import '../widgets/channel_avatar.dart';

/// Premium futuristic sports match card with neon glow effects.
/// 16:9 landscape aspect ratio with glassmorphism and broadcast graphics.
class PremiumSportsCard extends StatefulWidget {
  final MatchModel match;
  final VoidCallback? onTap;

  const PremiumSportsCard({
    super.key,
    required this.match,
    this.onTap,
  });

  @override
  State<PremiumSportsCard> createState() => _PremiumSportsCardState();
}

class _PremiumSportsCardState extends State<PremiumSportsCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (widget.match.isUpcoming) {
      _startTick();
    }
  }

  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final isLive = m.isLive || BdtTime.untilKickoff(m.matchDate).inSeconds <= 0;
    final isFinished = m.isFinished;
    final hasScores = m.scoreA.trim().isNotEmpty || m.scoreB.trim().isNotEmpty;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF05070D),
                Color(0xFF0A0F1A),
                Color(0xFF05070D),
              ],
            ),
            border: Border.all(
              color: isLive
                  ? const Color(0xFF2979FF).withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.15),
              width: 1.2,
            ),
            boxShadow: [
              // Red glow on left
              BoxShadow(
                color: const Color(0xFFFF1744).withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(-15, 0),
                spreadRadius: -10,
              ),
              // Blue glow on right
              BoxShadow(
                color: const Color(0xFF2979FF).withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(15, 0),
                spreadRadius: -10,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background stadium atmosphere effects
              Positioned.fill(
                child: _StadiumAtmosphere(isLive: isLive),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Date and Live badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Date
                        _DateDisplay(matchDate: m.matchDate),
                        // Live badge
                        if (isLive) const _LiveBadge(),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    // Center: Teams and score
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Team A
                        _TeamDisplay(
                          teamName: m.teamA,
                          logoUrl: m.teamALogo,
                          sport: m.sport,
                          isLeft: true,
                        ),
                        
                        // Score
                        if (hasScores && (isLive || isFinished))
                          _ScoreDisplay(
                            scoreA: m.scoreA,
                            scoreB: m.scoreB,
                          )
                        else if (!isLive && !isFinished)
                          _TimeDisplay(matchDate: m.matchDate)
                        else
                          const _LiveIndicator(),
                        
                        // Team B
                        _TeamDisplay(
                          teamName: m.teamB,
                          logoUrl: m.teamBLogo,
                          sport: m.sport,
                          isLeft: false,
                        ),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    // Bottom: Countdown button
                    if (!isLive && !isFinished)
                      _CountdownButton(matchDate: m.matchDate),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stadium atmosphere background with particles and glow effects
class _StadiumAtmosphere extends StatelessWidget {
  final bool isLive;

  const _StadiumAtmosphere({required this.isLive});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Red particles on left
        Positioned(
          left: -20,
          top: 0,
          bottom: 0,
          width: 100,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFFFF1744).withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Blue particles on right
        Positioned(
          right: -20,
          top: 0,
          bottom: 0,
          width: 100,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  const Color(0xFF2979FF).withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Soft smoke effect
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [
                  Colors.white.withValues(alpha: 0.03),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Date display with calendar icon
class _DateDisplay extends StatelessWidget {
  final DateTime matchDate;

  const _DateDisplay({required this.matchDate});

  @override
  Widget build(BuildContext context) {
    final bdt = BdtTime.fromUtc(BdtTime.kickoffUtc(matchDate));
    final dayName = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][bdt.weekday - 1];
    final day = bdt.day.toString().padLeft(2, '0');
    final month = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'][bdt.month - 1];

    return Row(
      children: [
        const Icon(
          Icons.calendar_today_outlined,
          size: 16,
          color: Colors.white70,
        ),
        const SizedBox(width: 8),
        Text(
          '$dayName $day $month',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

/// Live badge with glossy effect
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF1744),
            const Color(0xFFFF1744).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF1744).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white,
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Team display with metallic shield badge
class _TeamDisplay extends StatelessWidget {
  final String teamName;
  final String? logoUrl;
  final String sport;
  final bool isLeft;

  const _TeamDisplay({
    required this.teamName,
    this.logoUrl,
    required this.sport,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Metallic shield badge with flag/logo
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.2),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: TeamAvatar(
              name: teamName,
              logoUrl: logoUrl,
              sport: sport,
              size: 56,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Team name
        SizedBox(
          width: 100,
          child: Text(
            teamName.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Score display with glowing numbers
class _ScoreDisplay extends StatelessWidget {
  final String scoreA;
  final String scoreB;

  const _ScoreDisplay({
    required this.scoreA,
    required this.scoreB,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Score A with red glow
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF1744).withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              scoreA,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                shadows: [
                  Shadow(
                    color: Color(0xFFFF1744),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            '-',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          // Score B with blue glow
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFF2979FF).withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              scoreB,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                shadows: [
                  Shadow(
                    color: Color(0xFF2979FF),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Time display for upcoming matches
class _TimeDisplay extends StatelessWidget {
  final DateTime matchDate;

  const _TimeDisplay({required this.matchDate});

  @override
  Widget build(BuildContext context) {
    final timeStr = BdtTime.formatClock12h(matchDate);
    
    return Row(
      children: [
        const Icon(
          Icons.access_time,
          size: 20,
          color: Colors.white70,
        ),
        const SizedBox(width: 8),
        Text(
          timeStr,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Live indicator for live matches without scores
class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFFFF1744),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF1744).withValues(alpha: 0.6),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'LIVE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

/// Countdown button for upcoming matches
class _CountdownButton extends StatelessWidget {
  final DateTime matchDate;

  const _CountdownButton({required this.matchDate});

  @override
  Widget build(BuildContext context) {
    final remaining = BdtTime.untilKickoff(matchDate);
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    
    String countdownText;
    if (hours > 0) {
      countdownText = 'STARTS IN $hours HOUR${hours > 1 ? "S" : ""}';
    } else if (minutes > 0) {
      countdownText = 'STARTS IN $minutes MIN${minutes > 1 ? "S" : ""}';
    } else {
      countdownText = 'STARTING SOON';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.access_time_rounded,
            size: 18,
            color: Colors.white70,
          ),
          const SizedBox(width: 10),
          Text(
            countdownText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
