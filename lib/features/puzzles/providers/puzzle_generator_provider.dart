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
  final String? error;
  final double progress;

  const PuzzleGeneratorState({
    this.isGenerating = false,
    this.isLoading = false,
    this.puzzles = const [],
    this.error,
    this.progress = 0,
  });

  PuzzleGeneratorState copyWith({
    bool? isGenerating,
    bool? isLoading,
    List<Puzzle>? puzzles,
    String? error,
    double? progress,
    bool clearError = false,
  }) {
    return PuzzleGeneratorState(
      isGenerating: isGenerating ?? this.isGenerating,
      isLoading: isLoading ?? this.isLoading,
      puzzles: puzzles ?? this.puzzles,
      error: clearError ? null : (error ?? this.error),
      progress: progress ?? this.progress,
    );
  }
}

/// Notifier for puzzle generation
class PuzzleGeneratorNotifier extends StateNotifier<PuzzleGeneratorState> {
  PuzzleGenerator? _generator;
  final String? _userId;

  PuzzleGeneratorNotifier(this._userId) : super(const PuzzleGeneratorState()) {
    _loadPuzzlesFromServer();
  }

  /// Load puzzles from the server
  Future<void> _loadPuzzlesFromServer() async {
    if (_userId == null || _userId.startsWith('guest_')) return;

    state = state.copyWith(isLoading: true);

    try {
      final response = await SupabaseService.client.rpc(
        'get_all_user_puzzles',
        params: {'p_user_id': _userId},
      );

      if (response != null && response is List) {
        final puzzles = response.map<Puzzle>((data) {
          return Puzzle(
            id: data['id']?.toString() ?? '',
            fen: data['fen'] as String? ?? '',
            solution: _parseSolution(data['solution_uci'] as String?),
            solutionSan: _parseSolution(data['solution_san'] as String?),
            rating: data['rating'] as int? ?? 1500,
            theme: _parseTheme(data['theme'] as String?),
            description: data['classification'] as String?,
          );
        }).where((p) => p.fen.isNotEmpty && p.solution.isNotEmpty).toList();

        state = state.copyWith(
          isLoading: false,
          puzzles: puzzles,
        );
        debugPrint('Loaded ${puzzles.length} puzzles from server');
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      debugPrint('Error loading puzzles from server: $e');
      state = state.copyWith(isLoading: false);
    }
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
      default:
        return PuzzleTheme.tactics;
    }
  }

  /// Refresh puzzles from server
  Future<void> refresh() async {
    await _loadPuzzlesFromServer();
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
