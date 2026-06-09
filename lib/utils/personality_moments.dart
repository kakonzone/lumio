import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:confetti/confetti.dart';
import 'package:lumio_tv/l10n/strings.dart';
import '../utils/sound_manager.dart';

/// Personality moment types
enum PersonalityMoment {
  notFound,
  firstFavorite,
  milestone100Hours,
}

/// Manager for personality moments
/// 
/// Subtle, tasteful moments that add character without being intrusive
class PersonalityMomentsManager {
  static final PersonalityMomentsManager _instance = PersonalityMomentsManager._internal();
  factory PersonalityMomentsManager() => _instance;
  PersonalityMomentsManager._internal();

  // State tracking
  bool _firstFavoriteAdded = false;
  int _totalWatchedHours = 0;
  bool _milestone100HoursShown = false;

  /// Initialize and load persisted state
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _firstFavoriteAdded = prefs.getBool('first_favorite_added') ?? false;
    _totalWatchedHours = prefs.getInt('total_watched_hours') ?? 0;
    _milestone100HoursShown = prefs.getBool('milestone_100_hours_shown') ?? false;
  }

  /// Check if first favorite has been added
  bool get firstFavoriteAdded => _firstFavoriteAdded;

  /// Get total watched hours
  int get totalWatchedHours => _totalWatchedHours;

  /// Check if 100 hour milestone has been shown
  bool get milestone100HoursShown => _milestone100HoursShown;

  /// Mark first favorite as added
  Future<void> markFirstFavoriteAdded() async {
    _firstFavoriteAdded = true;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_favorite_added', true);
  }

  /// Increment watched hours
  Future<void> incrementWatchedHours() async {
    _totalWatchedHours++;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('total_watched_hours', _totalWatchedHours);
    
    // Check for milestone
    if (_totalWatchedHours == 100 && !_milestone100HoursShown) {
      _milestone100HoursShown = true;
      await prefs.setBool('milestone_100_hours_shown', true);
    }
  }

  /// Check if first favorite moment should be shown
  bool shouldShowFirstFavoriteMoment() {
    return !_firstFavoriteAdded;
  }

  /// Check if 100 hour milestone should be shown
  bool shouldShow100HoursMoment() {
    return _totalWatchedHours >= 100 && !_milestone100HoursShown;
  }

  /// Reset first favorite (for testing)
  Future<void> resetFirstFavorite() async {
    _firstFavoriteAdded = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('first_favorite_added');
  }

  /// Reset milestone (for testing)
  Future<void> resetMilestone() async {
    _milestone100HoursShown = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('milestone_100_hours_shown');
  }

  /// Reset watched hours (for testing)
  Future<void> resetWatchedHours() async {
    _totalWatchedHours = 0;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('total_watched_hours', 0);
  }
}

/// 404/Not Found personality moment
class NotFoundMoment extends StatelessWidget {
  const NotFoundMoment({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIcons.magnifyingGlass(),
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            Strings.notFoundMessage,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

/// First favorite celebration moment
class FirstFavoriteMoment extends StatefulWidget {
  final Widget child;

  const FirstFavoriteMoment({
    super.key,
    required this.child,
  });

  @override
  State<FirstFavoriteMoment> createState() => _FirstFavoriteMomentState();
}

class _FirstFavoriteMomentState extends State<FirstFavoriteMoment>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(seconds: 1),
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            particleDrag: 0.05,
            emissionFrequency: 0.05,
            numberOfParticles: 30,
            gravity: 0.1,
            shouldLoop: false,
            colors: const [
              Color(0xFFFF6B1A), // Accent
              Color(0xFFFFFFFF), // White
              Color(0xFF22C55E), // Success
            ],
          ),
        ),
        // Heart pulse animation overlay
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              );
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFFF6B1A),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 100 hours milestone toast
class Milestone100HoursMoment extends StatelessWidget {
  const Milestone100HoursMoment({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIcons.confetti(),
            color: const Color(0xFFFF6B1A),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Strings.milestone100HoursTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  Strings.milestone100HoursMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Widget to trigger first favorite moment
/// 
/// Wrap your favorite button with this:
/// ```dart
/// FirstFavoriteTrigger(
///   onTap: () {
///     // Your add to favorites logic
///   },
///   child: FavoriteButton(),
/// )
/// ```
class FirstFavoriteTrigger extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const FirstFavoriteTrigger({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<FirstFavoriteTrigger> createState() => _FirstFavoriteTriggerState();
}

class _FirstFavoriteTriggerState extends State<FirstFavoriteTrigger> {
  bool _shouldShowMoment = false;

  @override
  void initState() {
    super.initState();
    _checkMoment();
  }

  Future<void> _checkMoment() async {
    final manager = PersonalityMomentsManager();
    await manager.initialize();
    
    if (mounted) {
      setState(() {
        _shouldShowMoment = manager.shouldShowFirstFavoriteMoment();
      });
    }
  }

  void _handleTap() async {
    if (_shouldShowMoment) {
      setState(() {
        _shouldShowMoment = false;
      });
    }
    
    widget.onTap();
    
    if (_shouldShowMoment) {
      final manager = PersonalityMomentsManager();
      await manager.markFirstFavoriteAdded();
      await SoundManager.success();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldShowMoment) {
      return FirstFavoriteMoment(
        child: GestureDetector(
          onTap: _handleTap,
          child: widget.child,
        ),
      );
    }
    
    return GestureDetector(
      onTap: _handleTap,
      child: widget.child,
    );
  }
}

/// Widget to check and show 100 hours milestone
class Milestone100HoursChecker extends StatefulWidget {
  final Widget child;

  const Milestone100HoursChecker({
    super.key,
    required this.child,
  });

  @override
  State<Milestone100HoursChecker> createState() => _Milestone100HoursCheckerState();
}

class _Milestone100HoursCheckerState extends State<Milestone100HoursChecker> {
  @override
  void initState() {
    super.initState();
    _checkMilestone();
  }

  Future<void> _checkMilestone() async {
    final manager = PersonalityMomentsManager();
    await manager.initialize();
    
    if (manager.shouldShow100HoursMoment() && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMilestoneToast();
      });
    }
  }

  void _showMilestoneToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: const Milestone100HoursMoment(),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    SoundManager.achievement();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
