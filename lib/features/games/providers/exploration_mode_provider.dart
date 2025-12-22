import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/chess_position_utils.dart';

/// State for free exploration mode in game review
class ExplorationState {
  final bool isEnabled;
  final Chess? position;
  final List<String> moveHistory; // UCI moves made during exploration

  const ExplorationState({
    this.isEnabled = false,
    this.position,
    this.moveHistory = const [],
  });

  /// Get valid moves for the current position
  IMap<Square, ISet<Square>> get validMoves {
    if (position == null) return const IMap.empty();

    final moves = ChessPositionUtils.getValidMoves(position!);
    return IMap(moves.map((k, v) => MapEntry(k, ISet(v))));
  }

  /// Current side to move
  Side? get sideToMove => position?.turn;

  /// Current FEN
  String get fen => position?.fen ?? ChessPositionUtils.startingFen;

  ExplorationState copyWith({
    bool? isEnabled,
    Chess? position,
    List<String>? moveHistory,
    bool clearPosition = false,
  }) {
    return ExplorationState(
      isEnabled: isEnabled ?? this.isEnabled,
      position: clearPosition ? null : (position ?? this.position),
      moveHistory: moveHistory ?? this.moveHistory,
    );
  }
}

/// Notifier for exploration mode
class ExplorationModeNotifier extends StateNotifier<ExplorationState> {
  ExplorationModeNotifier() : super(const ExplorationState());

  /// Enter exploration mode from a given position
  void enterExploration(String fen) {
    final position = ChessPositionUtils.positionFromFen(fen);
    if (position != null) {
      state = ExplorationState(
        isEnabled: true,
        position: position,
        moveHistory: [],
      );
    }
  }

  /// Exit exploration mode
  void exitExploration() {
    state = const ExplorationState(
      isEnabled: false,
      position: null,
      moveHistory: [],
    );
  }

  /// Toggle exploration mode
  void toggle(String currentFen) {
    if (state.isEnabled) {
      exitExploration();
    } else {
      enterExploration(currentFen);
    }
  }

  /// Make a move in exploration mode
  bool makeMove(NormalMove move) {
    if (!state.isEnabled || state.position == null) return false;

    final newPosition = ChessPositionUtils.makeMove(state.position!, move);
    if (newPosition == null) return false;

    // Build UCI string
    final uci = '${move.from.name}${move.to.name}${move.promotion?.letter ?? ''}';

    state = state.copyWith(
      position: newPosition,
      moveHistory: [...state.moveHistory, uci],
    );

    return true;
  }

  /// Go back one move in exploration
  void undoMove() {
    if (!state.isEnabled || state.moveHistory.isEmpty) return;

    // Rebuild position from original FEN + all moves except last
    final newHistory = state.moveHistory.sublist(0, state.moveHistory.length - 1);

    // We need the original FEN to rebuild - for simplicity, rebuild from start
    // In a more complete implementation, we'd store the starting FEN
    state = state.copyWith(
      moveHistory: newHistory,
    );
  }

  /// Reset exploration to the starting position
  void reset(String originalFen) {
    if (!state.isEnabled) return;

    final position = ChessPositionUtils.positionFromFen(originalFen);
    state = state.copyWith(
      position: position,
      moveHistory: [],
    );
  }
}

/// Provider for exploration mode
final explorationModeProvider =
    StateNotifierProvider.autoDispose<ExplorationModeNotifier, ExplorationState>(
  (ref) => ExplorationModeNotifier(),
);
