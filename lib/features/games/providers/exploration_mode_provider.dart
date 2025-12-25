import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/global_stockfish_manager.dart';
import '../../analysis/services/stockfish_service.dart';
import '../utils/chess_position_utils.dart';

/// State for seamless exploration in game review
/// Users can always drag pieces. When they deviate from the game, they're "exploring"
class ExplorationState {
  final bool isExploring; // True when user made moves not in original game
  final Chess? currentPosition; // Current board position
  final List<String> explorationMoves; // UCI moves made during exploration
  final String? originalFen; // The FEN before exploration started
  final int? originalMoveIndex; // The move index before exploration started
  final int? evalCp; // Centipawn evaluation for current exploration position
  final bool isEvaluating; // Whether engine is currently evaluating

  const ExplorationState({
    this.isExploring = false,
    this.currentPosition,
    this.explorationMoves = const [],
    this.originalFen,
    this.originalMoveIndex,
    this.evalCp,
    this.isEvaluating = false,
  });

  /// Get valid moves for the current position
  IMap<Square, ISet<Square>> get validMoves {
    if (currentPosition == null) return const IMap.empty();
    final moves = ChessPositionUtils.getValidMoves(currentPosition!);
    return IMap(moves.map((k, v) => MapEntry(k, ISet(v))));
  }

  /// Current side to move
  Side get sideToMove => currentPosition?.turn ?? Side.white;

  /// Current FEN
  String get fen => currentPosition?.fen ?? ChessPositionUtils.startingFen;

  /// Can undo exploration moves
  bool get canUndo => isExploring && explorationMoves.isNotEmpty;

  ExplorationState copyWith({
    bool? isExploring,
    Chess? currentPosition,
    List<String>? explorationMoves,
    String? originalFen,
    int? originalMoveIndex,
    int? evalCp,
    bool? isEvaluating,
    bool clearPosition = false,
    bool clearEval = false,
  }) {
    return ExplorationState(
      isExploring: isExploring ?? this.isExploring,
      currentPosition: clearPosition ? null : (currentPosition ?? this.currentPosition),
      explorationMoves: explorationMoves ?? this.explorationMoves,
      originalFen: originalFen ?? this.originalFen,
      originalMoveIndex: originalMoveIndex ?? this.originalMoveIndex,
      evalCp: clearEval ? null : (evalCp ?? this.evalCp),
      isEvaluating: isEvaluating ?? this.isEvaluating,
    );
  }
}

/// Notifier for seamless exploration mode
class ExplorationModeNotifier extends StateNotifier<ExplorationState> {
  static const _ownerId = 'shared'; // Use shared owner to reuse pre-loaded instance
  StockfishService? _engine;
  bool _isEngineReady = false;

  ExplorationModeNotifier() : super(const ExplorationState());

  @override
  void dispose() {
    // Don't release 'shared' - it's meant to be kept alive
    _engine = null;
    _isEngineReady = false;
    super.dispose();
  }

  Future<void> _acquireEngine() async {
    if (_isEngineReady && _engine != null) return;

    try {
      _engine = await GlobalStockfishManager.instance.acquire(
        _ownerId,
        config: const StockfishConfig(maxDepth: 12, multiPv: 1),
      );
      _isEngineReady = true;
    } catch (e) {
      _isEngineReady = false;
      _engine = null;
    }
  }

  void _releaseEngine() {
    // Don't release 'shared' - just clear local reference
    _engine = null;
    _isEngineReady = false;
  }

  /// Evaluate the current exploration position
  Future<void> _evaluatePosition() async {
    if (!state.isExploring || state.currentPosition == null) return;

    state = state.copyWith(isEvaluating: true);

    try {
      await _acquireEngine();
      if (_engine == null) {
        state = state.copyWith(isEvaluating: false);
        return;
      }

      final fen = state.fen;
      final sideToMove = state.sideToMove;

      // Quick evaluation with depth 12
      final result = await _engine!.evaluatePosition(fen, depth: 12);

      if (!mounted) return;

      if (result != null && result.containsKey('score')) {
        int evalCp = result['score'] as int;
        // Normalize to white's perspective
        if (sideToMove == Side.black) {
          evalCp = -evalCp;
        }
        state = state.copyWith(evalCp: evalCp, isEvaluating: false);
      } else {
        state = state.copyWith(isEvaluating: false);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isEvaluating: false);
      }
    }
  }

  /// Update the current position (called when game review moves)
  void setPosition(String fen, int moveIndex) {
    if (state.isExploring) return; // Don't update if exploring

    final position = ChessPositionUtils.positionFromFen(fen);
    state = state.copyWith(
      currentPosition: position,
      originalFen: fen,
      originalMoveIndex: moveIndex,
    );
  }

  /// Make a move - could be from game history or exploration
  /// Returns true if this is an exploration move (deviated from game)
  bool makeMove(NormalMove move, {String? expectedUci}) {
    if (state.currentPosition == null) return false;

    // Convert standard castling notation to dartchess format
    // dartchess uses king-to-rook (e1h1), but user clicks king-to-final (e1g1)
    var actualMove = move;
    final king = state.currentPosition!.board.kingOf(state.currentPosition!.turn);
    if (king != null && move.from == king) {
      // White kingside: e1g1 -> e1h1
      if (move.from == Square.e1 && move.to == Square.g1) {
        actualMove = NormalMove(from: Square.e1, to: Square.h1);
      }
      // White queenside: e1c1 -> e1a1
      else if (move.from == Square.e1 && move.to == Square.c1) {
        actualMove = NormalMove(from: Square.e1, to: Square.a1);
      }
      // Black kingside: e8g8 -> e8h8
      else if (move.from == Square.e8 && move.to == Square.g8) {
        actualMove = NormalMove(from: Square.e8, to: Square.h8);
      }
      // Black queenside: e8c8 -> e8a8
      else if (move.from == Square.e8 && move.to == Square.c8) {
        actualMove = NormalMove(from: Square.e8, to: Square.a8);
      }
    }

    final newPosition = ChessPositionUtils.makeMove(state.currentPosition!, actualMove);
    if (newPosition == null) return false;

    // Build UCI string for this move
    final uci = '${actualMove.from.name}${actualMove.to.name}${actualMove.promotion?.letter ?? ''}';

    // Check if this matches the expected next move in game history
    if (!state.isExploring && expectedUci != null && uci == expectedUci) {
      // This is the next game move - just update position without entering exploration
      state = state.copyWith(currentPosition: newPosition);
      return false;
    }

    // This is an exploration move (different from game history)
    state = state.copyWith(
      isExploring: true,
      currentPosition: newPosition,
      explorationMoves: [...state.explorationMoves, uci],
      // Keep original fen/moveIndex from before exploration started
      originalFen: state.isExploring ? state.originalFen : state.originalFen,
      originalMoveIndex: state.isExploring ? state.originalMoveIndex : state.originalMoveIndex,
      clearEval: true, // Clear previous eval while we compute new one
    );

    // Trigger evaluation for the new position
    _evaluatePosition();

    return true;
  }

  /// Undo the last exploration move
  void undoMove() {
    if (!state.isExploring || state.explorationMoves.isEmpty || state.originalFen == null) return;

    final newHistory = state.explorationMoves.sublist(0, state.explorationMoves.length - 1);

    if (newHistory.isEmpty) {
      // Back to original position - exit exploration
      final originalPosition = ChessPositionUtils.positionFromFen(state.originalFen!);
      state = state.copyWith(
        isExploring: false,
        currentPosition: originalPosition,
        explorationMoves: [],
        clearEval: true,
      );
      _releaseEngine();
    } else {
      // Rebuild position from original FEN + remaining moves
      Chess? position = ChessPositionUtils.positionFromFen(state.originalFen!);
      if (position != null) {
        for (final uci in newHistory) {
          final move = ChessPositionUtils.parseUciMove(uci);
          if (move != null) {
            position = ChessPositionUtils.makeMove(position!, move);
            if (position == null) break;
          }
        }
      }
      state = state.copyWith(
        currentPosition: position,
        explorationMoves: newHistory,
        clearEval: true,
      );
      // Evaluate the new position after undo
      _evaluatePosition();
    }
  }

  /// Return to game (exit exploration mode)
  void returnToGame() {
    if (!state.isExploring || state.originalFen == null) return;

    final originalPosition = ChessPositionUtils.positionFromFen(state.originalFen!);
    state = state.copyWith(
      isExploring: false,
      currentPosition: originalPosition,
      explorationMoves: [],
      clearEval: true,
    );
    _releaseEngine();
  }

  /// Reset state completely
  void reset() {
    _releaseEngine();
    state = const ExplorationState();
  }
}

/// Provider for exploration mode
final explorationModeProvider =
    StateNotifierProvider.autoDispose<ExplorationModeNotifier, ExplorationState>(
  (ref) => ExplorationModeNotifier(),
);
