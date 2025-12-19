import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/puzzle.dart';
import '../services/puzzle_generator.dart';

/// State for puzzle generation
class PuzzleGeneratorState {
  final bool isGenerating;
  final List<Puzzle> puzzles;
  final String? error;
  final double progress;

  const PuzzleGeneratorState({
    this.isGenerating = false,
    this.puzzles = const [],
    this.error,
    this.progress = 0,
  });

  PuzzleGeneratorState copyWith({
    bool? isGenerating,
    List<Puzzle>? puzzles,
    String? error,
    double? progress,
    bool clearError = false,
  }) {
    return PuzzleGeneratorState(
      isGenerating: isGenerating ?? this.isGenerating,
      puzzles: puzzles ?? this.puzzles,
      error: clearError ? null : (error ?? this.error),
      progress: progress ?? this.progress,
    );
  }
}

/// Notifier for puzzle generation
class PuzzleGeneratorNotifier extends StateNotifier<PuzzleGeneratorState> {
  PuzzleGenerator? _generator;

  PuzzleGeneratorNotifier() : super(const PuzzleGeneratorState());

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
  return PuzzleGeneratorNotifier();
});

/// Provider for accessing generated puzzles
final generatedPuzzlesProvider = Provider<List<Puzzle>>((ref) {
  return ref.watch(puzzleGeneratorProvider).puzzles;
});
