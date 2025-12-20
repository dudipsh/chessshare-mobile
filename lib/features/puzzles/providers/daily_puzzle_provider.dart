import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../gamification/models/xp_models.dart';
import '../../gamification/providers/gamification_provider.dart';
import '../models/puzzle.dart';

/// State for daily puzzle feature
class DailyPuzzleState {
  final Puzzle? puzzle;
  final bool isLoading;
  final bool isSolved;
  final DateTime? solvedAt;
  final int streak; // Days in a row solving daily puzzle
  final String? error;

  const DailyPuzzleState({
    this.puzzle,
    this.isLoading = false,
    this.isSolved = false,
    this.solvedAt,
    this.streak = 0,
    this.error,
  });

  DailyPuzzleState copyWith({
    Puzzle? puzzle,
    bool? isLoading,
    bool? isSolved,
    DateTime? solvedAt,
    int? streak,
    String? error,
    bool clearError = false,
  }) {
    return DailyPuzzleState(
      puzzle: puzzle ?? this.puzzle,
      isLoading: isLoading ?? this.isLoading,
      isSolved: isSolved ?? this.isSolved,
      solvedAt: solvedAt ?? this.solvedAt,
      streak: streak ?? this.streak,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for daily puzzle
class DailyPuzzleNotifier extends StateNotifier<DailyPuzzleState> {
  final String? _userId;
  final GamificationNotifier? _gamificationNotifier;

  static const _prefsKeyLastSolvedDate = 'daily_puzzle_last_solved';
  static const _prefsKeyStreak = 'daily_puzzle_streak';
  static const _prefsKeyPuzzleId = 'daily_puzzle_id';

  DailyPuzzleNotifier(this._userId, this._gamificationNotifier)
      : super(const DailyPuzzleState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadStreak();
    await _loadDailyPuzzle();
  }

  /// Load the current streak from preferences
  Future<void> _loadStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final streak = prefs.getInt(_prefsKeyStreak) ?? 0;
      final lastSolvedStr = prefs.getString(_prefsKeyLastSolvedDate);

      if (lastSolvedStr != null) {
        final lastSolved = DateTime.parse(lastSolvedStr);
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final lastSolvedDate = DateTime(lastSolved.year, lastSolved.month, lastSolved.day);

        // Check if solved today
        final isSolvedToday = todayDate.isAtSameMomentAs(lastSolvedDate);

        // Check if streak is still valid (solved yesterday or today)
        final daysDiff = todayDate.difference(lastSolvedDate).inDays;
        final validStreak = daysDiff <= 1 ? streak : 0;

        state = state.copyWith(
          streak: validStreak,
          isSolved: isSolvedToday,
          solvedAt: isSolvedToday ? lastSolved : null,
        );
      }
    } catch (e) {
      debugPrint('Error loading daily puzzle streak: $e');
    }
  }

  /// Load today's daily puzzle
  Future<void> _loadDailyPuzzle() async {
    if (_userId == null || _userId!.startsWith('guest_')) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Try to get daily puzzle from server
      final response = await SupabaseService.client.rpc(
        'get_daily_puzzle',
        params: {'p_user_id': _userId},
      );

      if (response != null) {
        final puzzle = _parsePuzzle(response);
        if (puzzle != null) {
          state = state.copyWith(
            puzzle: puzzle,
            isLoading: false,
          );
          return;
        }
      }

      // Fallback: Get a random puzzle from user's puzzles
      await _loadRandomPuzzle();
    } catch (e) {
      debugPrint('Error loading daily puzzle: $e');
      // Fallback to random puzzle
      await _loadRandomPuzzle();
    }
  }

  /// Load a random puzzle as fallback
  Future<void> _loadRandomPuzzle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';
      final savedPuzzleId = prefs.getString(_prefsKeyPuzzleId);

      // Check if we already have a puzzle for today
      if (savedPuzzleId != null && savedPuzzleId.startsWith(todayKey)) {
        final puzzleId = savedPuzzleId.split(':').last;
        // Try to load this specific puzzle
        final response = await SupabaseService.client
            .from('user_puzzles')
            .select()
            .eq('id', puzzleId)
            .maybeSingle();

        if (response != null) {
          final puzzle = _parsePuzzle(response);
          if (puzzle != null) {
            state = state.copyWith(puzzle: puzzle, isLoading: false);
            return;
          }
        }
      }

      // Get a random unsolved puzzle
      final response = await SupabaseService.client
          .from('user_puzzles')
          .select()
          .eq('profile_id', _userId!)
          .eq('completed', false)
          .limit(1);

      if (response != null && (response as List).isNotEmpty) {
        final puzzle = _parsePuzzle(response.first);
        if (puzzle != null) {
          // Save puzzle ID for today
          await prefs.setString(_prefsKeyPuzzleId, '$todayKey:${puzzle.id}');
          state = state.copyWith(puzzle: puzzle, isLoading: false);
          return;
        }
      }

      // No puzzles available - create a default one
      state = state.copyWith(
        puzzle: _createDefaultPuzzle(),
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error loading random puzzle: $e');
      state = state.copyWith(
        puzzle: _createDefaultPuzzle(),
        isLoading: false,
      );
    }
  }

  /// Mark the daily puzzle as solved
  Future<void> markSolved() async {
    if (state.isSolved) return;

    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    // Update streak
    int newStreak = state.streak + 1;

    await prefs.setString(_prefsKeyLastSolvedDate, now.toIso8601String());
    await prefs.setInt(_prefsKeyStreak, newStreak);

    state = state.copyWith(
      isSolved: true,
      solvedAt: now,
      streak: newStreak,
    );

    // Award XP
    _gamificationNotifier?.awardXp(
      XpEventType.dailyPuzzleSolve,
      relatedId: state.puzzle?.id,
    );

    // Record on server
    try {
      await SupabaseService.client.rpc('record_daily_puzzle_solve', params: {
        'p_user_id': _userId,
        'p_puzzle_id': state.puzzle?.id,
        'p_streak': newStreak,
      });
    } catch (e) {
      debugPrint('Error recording daily puzzle solve: $e');
    }
  }

  /// Refresh the daily puzzle
  Future<void> refresh() async {
    await _loadDailyPuzzle();
  }

  Puzzle? _parsePuzzle(Map<String, dynamic> data) {
    try {
      final fen = data['fen'] as String?;
      final solutionUci = data['solution_uci'] as String? ?? data['solution'] as String?;

      if (fen == null || solutionUci == null) return null;

      final solution = solutionUci.split(' ').where((s) => s.isNotEmpty).toList();
      if (solution.isEmpty) return null;

      return Puzzle(
        id: data['id']?.toString() ?? '',
        fen: fen,
        solution: solution,
        solutionSan: (data['solution_san'] as String?)?.split(' ').where((s) => s.isNotEmpty).toList() ?? [],
        rating: data['rating'] as int? ?? data['puzzle_rating'] as int? ?? 1500,
        theme: _parseTheme(data['theme'] as String? ?? data['marker_type'] as String?),
        description: data['description'] as String?,
      );
    } catch (e) {
      debugPrint('Error parsing puzzle: $e');
      return null;
    }
  }

  PuzzleTheme _parseTheme(String? theme) {
    if (theme == null) return PuzzleTheme.tactics;
    switch (theme.toLowerCase()) {
      case 'mate':
      case 'checkmate':
        return PuzzleTheme.mateIn1;
      case 'fork':
        return PuzzleTheme.fork;
      case 'pin':
        return PuzzleTheme.pin;
      default:
        return PuzzleTheme.tactics;
    }
  }

  /// Create a default puzzle if none available
  Puzzle _createDefaultPuzzle() {
    // Famous "Opera Game" position - Paul Morphy's brilliant finish
    return const Puzzle(
      id: 'default_daily',
      fen: 'r1b1kb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4',
      solution: ['h5f7'], // Qxf7#
      solutionSan: ['Qxf7#'],
      rating: 1200,
      theme: PuzzleTheme.mateIn1,
      description: 'Find the checkmate!',
    );
  }
}

/// Provider for daily puzzle
final dailyPuzzleProvider =
    StateNotifierProvider<DailyPuzzleNotifier, DailyPuzzleState>((ref) {
  final userId = ref.watch(authProvider).profile?.id;
  final gamificationNotifier = ref.read(gamificationProvider.notifier);
  return DailyPuzzleNotifier(userId, gamificationNotifier);
});

/// Provider to check if daily puzzle is available (not solved today)
final isDailyPuzzleAvailableProvider = Provider<bool>((ref) {
  final state = ref.watch(dailyPuzzleProvider);
  return state.puzzle != null && !state.isSolved;
});
