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
  final DateTime selectedDate; // Currently viewing this date's puzzle
  final Map<String, bool> solvedDates; // Track which dates are solved

  DailyPuzzleState({
    this.puzzle,
    this.isLoading = false,
    this.isSolved = false,
    this.solvedAt,
    this.streak = 0,
    this.error,
    DateTime? selectedDate,
    this.solvedDates = const {},
  }) : selectedDate = selectedDate ?? DateTime.now();

  DailyPuzzleState copyWith({
    Puzzle? puzzle,
    bool? isLoading,
    bool? isSolved,
    DateTime? solvedAt,
    int? streak,
    String? error,
    DateTime? selectedDate,
    Map<String, bool>? solvedDates,
    bool clearError = false,
  }) {
    return DailyPuzzleState(
      puzzle: puzzle ?? this.puzzle,
      isLoading: isLoading ?? this.isLoading,
      isSolved: isSolved ?? this.isSolved,
      solvedAt: solvedAt ?? this.solvedAt,
      streak: streak ?? this.streak,
      error: clearError ? null : (error ?? this.error),
      selectedDate: selectedDate ?? this.selectedDate,
      solvedDates: solvedDates ?? this.solvedDates,
    );
  }

  bool get isToday {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  String get dateKey => '${selectedDate.year}-${selectedDate.month}-${selectedDate.day}';
}

/// Notifier for daily puzzle
class DailyPuzzleNotifier extends StateNotifier<DailyPuzzleState> {
  final String? _userId;
  final GamificationNotifier? _gamificationNotifier;

  static const _prefsKeyLastSolvedDate = 'daily_puzzle_last_solved';
  static const _prefsKeyStreak = 'daily_puzzle_streak';
  static const _prefsKeySolvedDates = 'daily_puzzle_solved_dates';

  DailyPuzzleNotifier(this._userId, this._gamificationNotifier)
      : super(DailyPuzzleState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadSolvedDates();
    await _loadStreak();
    await _loadPuzzleForDate(state.selectedDate);
  }

  /// Load solved dates from preferences
  Future<void> _loadSolvedDates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final solvedList = prefs.getStringList(_prefsKeySolvedDates) ?? [];
      final solvedMap = <String, bool>{};
      for (final dateKey in solvedList) {
        solvedMap[dateKey] = true;
      }
      state = state.copyWith(solvedDates: solvedMap);
    } catch (e) {
      debugPrint('Error loading solved dates: $e');
    }
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

        // Check if streak is still valid (solved yesterday or today)
        final daysDiff = todayDate.difference(lastSolvedDate).inDays;
        final validStreak = daysDiff <= 1 ? streak : 0;

        state = state.copyWith(streak: validStreak);
      }
    } catch (e) {
      debugPrint('Error loading daily puzzle streak: $e');
    }
  }

  /// Navigate to previous day
  void previousDay() {
    final newDate = state.selectedDate.subtract(const Duration(days: 1));
    // Don't go more than 30 days back
    final minDate = DateTime.now().subtract(const Duration(days: 30));
    if (newDate.isAfter(minDate)) {
      _loadPuzzleForDate(newDate);
    }
  }

  /// Navigate to next day
  void nextDay() {
    final newDate = state.selectedDate.add(const Duration(days: 1));
    final today = DateTime.now();
    // Don't go past today
    if (newDate.year <= today.year &&
        newDate.month <= today.month &&
        newDate.day <= today.day) {
      _loadPuzzleForDate(newDate);
    }
  }

  /// Go to today
  void goToToday() {
    _loadPuzzleForDate(DateTime.now());
  }

  /// Load puzzle for a specific date
  Future<void> _loadPuzzleForDate(DateTime date) async {
    final dateKey = '${date.year}-${date.month}-${date.day}';
    final isSolved = state.solvedDates[dateKey] ?? false;

    state = state.copyWith(
      selectedDate: date,
      isLoading: true,
      isSolved: isSolved,
      puzzle: null,
      clearError: true,
    );

    try {
      // Generate a deterministic puzzle based on the date
      final puzzle = await _fetchPuzzleForDate(date);
      state = state.copyWith(
        puzzle: puzzle,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error loading puzzle for date $dateKey: $e');
      state = state.copyWith(
        puzzle: _createDefaultPuzzle(date),
        isLoading: false,
        error: 'Failed to load puzzle',
      );
    }
  }

  /// Fetch puzzle for a specific date (uses date as seed for consistent puzzle)
  Future<Puzzle> _fetchPuzzleForDate(DateTime date) async {
    final dateKey = '${date.year}-${date.month}-${date.day}';

    // Try to get from server first
    if (_userId != null && !_userId!.startsWith('guest_')) {
      try {
        final response = await SupabaseService.client.rpc(
          'get_daily_puzzle_for_date',
          params: {
            'p_user_id': _userId,
            'p_date': dateKey,
          },
        );

        if (response != null) {
          final puzzle = _parsePuzzle(response);
          if (puzzle != null) return puzzle;
        }
      } catch (e) {
        debugPrint('Server daily puzzle not available: $e');
      }

      // Fallback: Get a puzzle from user's puzzles using date as seed
      try {
        final seed = date.year * 10000 + date.month * 100 + date.day;
        final response = await SupabaseService.client
            .from('user_puzzles')
            .select()
            .eq('profile_id', _userId!)
            .order('created_at')
            .limit(100);

        if (response != null && (response as List).isNotEmpty) {
          // Use seed to pick consistent puzzle for this date
          final index = seed % response.length;
          final puzzle = _parsePuzzle(response[index]);
          if (puzzle != null) return puzzle;
        }
      } catch (e) {
        debugPrint('Error loading user puzzle: $e');
      }
    }

    return _createDefaultPuzzle(date);
  }

  /// Mark the daily puzzle as solved
  Future<void> markSolved() async {
    if (state.isSolved || !state.isToday) return;

    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final dateKey = state.dateKey;

    // Update solved dates
    final newSolvedDates = Map<String, bool>.from(state.solvedDates);
    newSolvedDates[dateKey] = true;

    // Save solved dates
    await prefs.setStringList(_prefsKeySolvedDates, newSolvedDates.keys.toList());

    // Update streak
    int newStreak = state.streak + 1;
    await prefs.setString(_prefsKeyLastSolvedDate, now.toIso8601String());
    await prefs.setInt(_prefsKeyStreak, newStreak);

    state = state.copyWith(
      isSolved: true,
      solvedAt: now,
      streak: newStreak,
      solvedDates: newSolvedDates,
    );

    // Award XP only for today's puzzle
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

  /// Refresh the current puzzle
  Future<void> refresh() async {
    await _loadPuzzleForDate(state.selectedDate);
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

  /// Create a default puzzle if none available (varies by date)
  Puzzle _createDefaultPuzzle(DateTime date) {
    // Collection of famous puzzles
    final puzzles = [
      const Puzzle(
        id: 'default_1',
        fen: 'r1b1kb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4',
        solution: ['h5f7'],
        solutionSan: ['Qxf7#'],
        rating: 1200,
        theme: PuzzleTheme.mateIn1,
        description: 'Find the checkmate!',
      ),
      const Puzzle(
        id: 'default_2',
        fen: 'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5Q2/PPPP1PPP/RNB1K1NR w KQkq - 4 4',
        solution: ['f3f7'],
        solutionSan: ['Qxf7#'],
        rating: 1100,
        theme: PuzzleTheme.mateIn1,
        description: 'Scholar\'s Mate',
      ),
      const Puzzle(
        id: 'default_3',
        fen: '6k1/5ppp/8/8/8/8/5PPP/4R1K1 w - - 0 1',
        solution: ['e1e8'],
        solutionSan: ['Re8#'],
        rating: 1000,
        theme: PuzzleTheme.mateIn1,
        description: 'Back rank mate',
      ),
    ];

    // Pick puzzle based on date
    final seed = date.year * 10000 + date.month * 100 + date.day;
    return puzzles[seed % puzzles.length];
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
