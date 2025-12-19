import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/puzzle.dart';
import '../services/puzzle_generator.dart';

/// State for puzzle generation
class PuzzleGeneratorState {
  final bool isGenerating;
  final bool isLoading;
  final List<Puzzle> puzzles;
  final List<Puzzle> difficultPuzzles; // Puzzles user struggled with
  final String? error;
  final double progress;
  final int totalPuzzleCount;

  const PuzzleGeneratorState({
    this.isGenerating = false,
    this.isLoading = false,
    this.puzzles = const [],
    this.difficultPuzzles = const [],
    this.error,
    this.progress = 0,
    this.totalPuzzleCount = 0,
  });

  PuzzleGeneratorState copyWith({
    bool? isGenerating,
    bool? isLoading,
    List<Puzzle>? puzzles,
    List<Puzzle>? difficultPuzzles,
    String? error,
    double? progress,
    int? totalPuzzleCount,
    bool clearError = false,
  }) {
    return PuzzleGeneratorState(
      isGenerating: isGenerating ?? this.isGenerating,
      isLoading: isLoading ?? this.isLoading,
      puzzles: puzzles ?? this.puzzles,
      difficultPuzzles: difficultPuzzles ?? this.difficultPuzzles,
      error: clearError ? null : (error ?? this.error),
      progress: progress ?? this.progress,
      totalPuzzleCount: totalPuzzleCount ?? this.totalPuzzleCount,
    );
  }
}

/// Notifier for puzzle generation
class PuzzleGeneratorNotifier extends StateNotifier<PuzzleGeneratorState> {
  PuzzleGenerator? _generator;
  final String? _userId;

  PuzzleGeneratorNotifier(this._userId) : super(const PuzzleGeneratorState()) {
    _loadAllPuzzles();
  }

  /// Load all puzzles (all user puzzles + difficult puzzles)
  Future<void> _loadAllPuzzles() async {
    if (_userId == null || _userId.startsWith('guest_')) return;

    state = state.copyWith(isLoading: true);

    try {
      // Load both in parallel
      await Future.wait([
        _loadPuzzlesFromServer(),
        _loadDifficultPuzzles(),
      ]);
    } catch (e) {
      debugPrint('Error loading puzzles: $e');
    }

    state = state.copyWith(isLoading: false);
  }

  /// Load all user puzzles from the server
  Future<void> _loadPuzzlesFromServer() async {
    if (_userId == null || _userId.startsWith('guest_')) return;

    try {
      final response = await SupabaseService.client.rpc(
        'get_all_user_puzzles',
        params: {'p_user_id': _userId},
      );

      if (response != null && response is List) {
        final puzzles = _parsePuzzles(response);
        state = state.copyWith(
          puzzles: puzzles,
          totalPuzzleCount: puzzles.length,
        );
        debugPrint('Loaded ${puzzles.length} puzzles from server');
      }
    } catch (e) {
      debugPrint('Error loading puzzles from server: $e');
    }
  }

  /// Load difficult puzzles (puzzles user struggled with)
  Future<void> _loadDifficultPuzzles() async {
    if (_userId == null || _userId.startsWith('guest_')) return;

    try {
      final response = await SupabaseService.client.rpc(
        'get_difficult_mistakes',
        params: {'p_limit': 50},
      );

      if (response != null && response is List) {
        final puzzles = _parsePuzzles(response);
        state = state.copyWith(difficultPuzzles: puzzles);
        debugPrint('Loaded ${puzzles.length} difficult puzzles');
      }
    } catch (e) {
      debugPrint('Error loading difficult puzzles: $e');
    }
  }

  /// Parse puzzle data from API response
  List<Puzzle> _parsePuzzles(List<dynamic> data) {
    return data.map<Puzzle>((item) {
      // Handle solution_sequence if available
      List<String> solution = _parseSolution(item['solution_uci'] as String?);
      List<String> solutionSan = _parseSolution(item['solution_san'] as String?);

      // If solution_sequence is available, use that for better puzzle experience
      if (item['solution_sequence'] != null && item['solution_sequence'] is List) {
        final sequence = item['solution_sequence'] as List;
        solution = sequence
            .where((s) => s['isUserMove'] == true)
            .map<String>((s) => s['move'] as String)
            .toList();
      }

      return Puzzle(
        id: item['id']?.toString() ?? '',
        fen: item['fen'] as String? ?? '',
        solution: solution,
        solutionSan: solutionSan,
        rating: item['puzzle_rating'] as int? ?? item['rating'] as int? ?? 1500,
        theme: _parseTheme(item['marker_type'] as String? ?? item['theme'] as String?),
        description: item['marker_type'] as String? ?? item['classification'] as String?,
        isPositive: item['is_positive_puzzle'] as bool? ?? false,
      );
    }).where((p) => p.fen.isNotEmpty && p.solution.isNotEmpty).toList();
  }

  List<String> _parseSolution(String? solution) {
    if (solution == null || solution.isEmpty) return [];
    return solution.split(' ').where((s) => s.isNotEmpty).toList();
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
      case 'sacrifice':
        return PuzzleTheme.sacrifice;
      case 'brilliant':
        return PuzzleTheme.sacrifice; // Brilliant moves often involve sacrifices
      case 'great':
        return PuzzleTheme.tactics;
      case 'blunder':
      case 'mistake':
      case 'miss':
      case 'inaccuracy':
        return PuzzleTheme.tactics;
      default:
        return PuzzleTheme.tactics;
    }
  }

  /// Refresh puzzles from server
  Future<void> refresh() async {
    await _loadAllPuzzles();
  }

  /// Generate puzzles from a PGN game
  Future<void> generateFromPgn(String pgn) async {
    if (state.isGenerating) return;

    state = state.copyWith(
      isGenerating: true,
      progress: 0,
      clearError: true,
    );

    try {
      _generator ??= PuzzleGenerator();
      await _generator!.initialize();

      state = state.copyWith(progress: 0.1);

      final puzzles = await _generator!.generateFromPgn(pgn);

      state = state.copyWith(
        isGenerating: false,
        puzzles: puzzles,
        progress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: 'Failed to generate puzzles: $e',
      );
    }
  }

  /// Generate puzzles from a list of FEN positions
  Future<void> generateFromPositions(List<String> fens) async {
    if (state.isGenerating) return;

    state = state.copyWith(
      isGenerating: true,
      progress: 0,
      clearError: true,
    );

    try {
      _generator ??= PuzzleGenerator();
      await _generator!.initialize();

      final puzzles = await _generator!.generateFromPositions(fens);

      state = state.copyWith(
        isGenerating: false,
        puzzles: puzzles,
        progress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: 'Failed to generate puzzles: $e',
      );
    }
  }

  /// Clear generated puzzles
  void clear() {
    state = const PuzzleGeneratorState();
  }

  @override
  void dispose() {
    _generator?.dispose();
    super.dispose();
  }
}

/// Provider for puzzle generation
final puzzleGeneratorProvider =
    StateNotifierProvider<PuzzleGeneratorNotifier, PuzzleGeneratorState>((ref) {
  final userId = ref.watch(authProvider).profile?.id;
  return PuzzleGeneratorNotifier(userId);
});

/// Provider for accessing generated puzzles
final generatedPuzzlesProvider = Provider<List<Puzzle>>((ref) {
  return ref.watch(puzzleGeneratorProvider).puzzles;
});
