import 'package:dartchess/dartchess.dart';
import 'package:chessground/chessground.dart' show ValidMoves;
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../gamification/models/xp_models.dart';
import '../../gamification/providers/gamification_provider.dart';
import '../models/puzzle.dart';

/// Marker types for visual feedback (shared with Study mode)
enum PuzzleMarkerType {
  none,
  hint,     // Yellow hint circle on piece to move
  correct,  // Green checkmark on correct move
  incorrect, // Red X on wrong move
}

class PuzzleSolveState {
  final Puzzle? puzzle;
  final String currentFen;
  final int currentMoveIndex;
  final PuzzleState state;
  final NormalMove? lastMove;
  final Side orientation;
  final ValidMoves validMoves;
  final String? feedback;
  final PuzzleMarkerType markerType;
  final Square? markerSquare;
  final int hintsUsed;

  const PuzzleSolveState({
    this.puzzle,
    this.currentFen = kInitialFEN,
    this.currentMoveIndex = 0,
    this.state = PuzzleState.ready,
    this.lastMove,
    this.orientation = Side.white,
    ValidMoves? validMoves,
    this.feedback,
    this.markerType = PuzzleMarkerType.none,
    this.markerSquare,
    this.hintsUsed = 0,
  }) : validMoves = validMoves ?? const IMapConst({});

  PuzzleSolveState copyWith({
    Puzzle? puzzle,
    String? currentFen,
    int? currentMoveIndex,
    PuzzleState? state,
    NormalMove? lastMove,
    Side? orientation,
    ValidMoves? validMoves,
    String? feedback,
    PuzzleMarkerType? markerType,
    Square? markerSquare,
    int? hintsUsed,
    bool clearLastMove = false,
    bool clearFeedback = false,
    bool clearMarker = false,
  }) {
    return PuzzleSolveState(
      puzzle: puzzle ?? this.puzzle,
      currentFen: currentFen ?? this.currentFen,
      currentMoveIndex: currentMoveIndex ?? this.currentMoveIndex,
      state: state ?? this.state,
      lastMove: clearLastMove ? null : (lastMove ?? this.lastMove),
      orientation: orientation ?? this.orientation,
      validMoves: validMoves ?? this.validMoves,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      markerType: clearMarker ? PuzzleMarkerType.none : (markerType ?? this.markerType),
      markerSquare: clearMarker ? null : (markerSquare ?? this.markerSquare),
      hintsUsed: hintsUsed ?? this.hintsUsed,
    );
  }

  bool get isComplete =>
      puzzle != null && currentMoveIndex >= puzzle!.solution.length;

  int get movesRemaining =>
      puzzle != null ? puzzle!.solution.length - currentMoveIndex : 0;
}

class PuzzleSolveNotifier extends StateNotifier<PuzzleSolveState> {
  final GamificationNotifier? _gamificationNotifier;
  Chess _position = Chess.initial;

  PuzzleSolveNotifier(this._gamificationNotifier) : super(const PuzzleSolveState());

  void loadPuzzle(Puzzle puzzle) {
    debugPrint('========================================');
    debugPrint('=== LOADING PUZZLE ===');
    debugPrint('Puzzle ID: ${puzzle.id}');
    debugPrint('Puzzle FEN: ${puzzle.fen}');
    debugPrint('Puzzle solution (${puzzle.solution.length} moves): ${puzzle.solution}');
    debugPrint('Puzzle solutionSan: ${puzzle.solutionSan}');
    debugPrint('Puzzle theme: ${puzzle.theme}');
    debugPrint('Puzzle rating: ${puzzle.rating}');
    debugPrint('========================================');

    try {
      _position = Chess.fromSetup(Setup.parseFen(puzzle.fen));
      debugPrint('FEN parsed successfully. Side to move: ${_position.turn}');

      // Validate puzzle solution before loading
      if (!_validatePuzzleSolution(puzzle)) {
        debugPrint('>>> PUZZLE VALIDATION FAILED <<<');
        state = state.copyWith(
          feedback: 'Invalid puzzle - please try another',
          state: PuzzleState.ready,
        );
        return;
      }

      // Orient board so puzzle solver plays from bottom
      final orientation = puzzle.sideToMove;
      debugPrint('Puzzle loaded successfully! Orientation: $orientation');
      debugPrint('Legal moves count: ${_position.legalMoves.length}');

      state = PuzzleSolveState(
        puzzle: puzzle,
        currentFen: puzzle.fen,
        currentMoveIndex: 0,
        state: PuzzleState.playing,
        orientation: orientation,
        validMoves: _convertToValidMoves(_position.legalMoves),
      );
      debugPrint('State updated. Current state: ${state.state}');
    } catch (e, stackTrace) {
      debugPrint('Failed to load puzzle: $e');
      debugPrint('Stack trace: $stackTrace');
      state = state.copyWith(
        feedback: 'Failed to load puzzle',
        state: PuzzleState.ready,
      );
    }
  }

  /// Validate that all moves in the puzzle solution are legal
  bool _validatePuzzleSolution(Puzzle puzzle) {
    // Validate puzzle has required data
    if (puzzle.fen.isEmpty) {
      debugPrint('Puzzle ${puzzle.id}: Empty FEN');
      return false;
    }
    if (puzzle.solution.isEmpty) {
      debugPrint('Puzzle ${puzzle.id}: Empty solution');
      return false;
    }

    try {
      Chess pos = Chess.fromSetup(Setup.parseFen(puzzle.fen));
      debugPrint('Validating puzzle ${puzzle.id}: FEN=${puzzle.fen}, solution=${puzzle.solution}');

      for (int i = 0; i < puzzle.solution.length; i++) {
        final uciMove = puzzle.solution[i];
        final move = _parseUciMove(uciMove);
        if (move == null) {
          debugPrint('Puzzle ${puzzle.id}: Invalid UCI format at move $i: $uciMove');
          return false;
        }

        // Check if move is legal
        if (!pos.legalMoves.containsKey(move.from)) {
          // Check if this is a "user moves only" puzzle (missing opponent responses)
          // The piece might belong to the wrong side because opponent's move is missing
          final board = pos.board;
          final piece = board.pieceAt(move.from);
          if (piece != null && piece.color != pos.turn) {
            debugPrint('Puzzle ${puzzle.id}: Move $i ($uciMove) is for ${piece.color} but it is ${pos.turn} turn');
            debugPrint('  This puzzle appears to have only user moves without opponent responses');
            debugPrint('  Consider clearing puzzle cache to reload from server');
            return false;
          }

          debugPrint('Puzzle ${puzzle.id}: No legal moves from ${move.from.name} at move $i');
          debugPrint('  Position: ${pos.fen}');
          debugPrint('  Legal moves: ${pos.legalMoves.keys.map((s) => s.name).join(", ")}');
          return false;
        }

        final legalTargets = pos.legalMoves[move.from];
        if (legalTargets == null || !legalTargets.squares.contains(move.to)) {
          debugPrint('Puzzle ${puzzle.id}: Move $uciMove not legal at move $i');
          debugPrint('  Position: ${pos.fen}');
          debugPrint('  Legal targets from ${move.from.name}: ${legalTargets?.squares.map((s) => s.name).join(", ") ?? "none"}');
          return false;
        }

        pos = pos.play(move) as Chess;
      }

      debugPrint('Puzzle ${puzzle.id}: Validation passed');
      return true;
    } catch (e) {
      debugPrint('Puzzle ${puzzle.id}: Validation error: $e');
      return false;
    }
  }

  void makeMove(NormalMove move) {
    final puzzle = state.puzzle;
    if (puzzle == null || state.state != PuzzleState.playing) return;

    // Convert standard castling notation to dartchess format
    // dartchess uses king-to-rook (e1h1), but user clicks king-to-final (e1g1)
    var actualMove = move;
    final king = _position.board.kingOf(_position.turn);
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

    final uci = '${actualMove.from.name}${actualMove.to.name}${actualMove.promotion?.letter ?? ''}';

    // Check if this is the correct move
    if (puzzle.isCorrectMove(uci, state.currentMoveIndex)) {
      // Correct move!
      _position = _position.play(actualMove) as Chess;

      final newIndex = state.currentMoveIndex + 1;

      if (newIndex >= puzzle.solution.length) {
        // Puzzle completed!
        state = state.copyWith(
          currentFen: _position.fen,
          currentMoveIndex: newIndex,
          lastMove: move,
          state: PuzzleState.completed,
          validMoves: IMap(),
          feedback: 'Excellent!',
          markerType: PuzzleMarkerType.correct,
          markerSquare: move.to,
        );

        // Award XP for solving the puzzle (regular puzzle, not daily)
        _gamificationNotifier?.awardXp(
          XpEventType.puzzleSolve,
          relatedId: puzzle.id,
        );
      } else {
        // Make opponent's response automatically - show correct marker briefly
        state = state.copyWith(
          currentFen: _position.fen,
          currentMoveIndex: newIndex,
          lastMove: move,
          state: PuzzleState.correct,
          feedback: 'Correct!',
          markerType: PuzzleMarkerType.correct,
          markerSquare: move.to,
        );

        // Schedule opponent move - clear marker when opponent moves
        Future.delayed(const Duration(milliseconds: 400), () {
          _makeOpponentMove();
        });
      }
    } else {
      // Wrong move - like Study mode:
      // 1. Show the piece in its wrong position
      // 2. Display X marker
      // 3. After delay, revert piece to original position

      // Save original position before making wrong move
      final originalFen = state.currentFen;

      // Temporarily play the wrong move to show it visually
      final tempPosition = _position.play(move) as Chess;

      state = state.copyWith(
        currentFen: tempPosition.fen,
        lastMove: move,
        state: PuzzleState.incorrect,
        feedback: 'Try again',
        markerType: PuzzleMarkerType.incorrect,
        markerSquare: move.to,
        validMoves: IMap(), // Disable moves while showing error
      );

      // After delay, revert to original position
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          state = state.copyWith(
            currentFen: originalFen,
            state: PuzzleState.playing,
            validMoves: _convertToValidMoves(_position.legalMoves),
            clearLastMove: true,
            clearFeedback: true,
            clearMarker: true,
          );
        }
      });
    }
  }

  void _makeOpponentMove() {
    final puzzle = state.puzzle;
    if (puzzle == null || state.currentMoveIndex >= puzzle.solution.length) {
      return;
    }

    final uciMove = puzzle.solution[state.currentMoveIndex];
    final move = _parseUciMove(uciMove);

    if (move != null) {
      try {
        // Verify the move is legal before playing
        if (!_position.legalMoves.containsKey(move.from)) {
          debugPrint('Opponent move ${uciMove} invalid: no moves from ${move.from.name}');
          state = state.copyWith(
            feedback: 'Puzzle error - invalid opponent move',
            state: PuzzleState.ready,
          );
          return;
        }

        _position = _position.play(move) as Chess;

        final newIndex = state.currentMoveIndex + 1;

        if (newIndex >= puzzle.solution.length) {
          // Puzzle completed after opponent's move (shouldn't happen normally)
          state = state.copyWith(
            currentFen: _position.fen,
            currentMoveIndex: newIndex,
            lastMove: move,
            state: PuzzleState.completed,
            validMoves: IMap(),
            feedback: 'Completed!',
          );
        } else {
          state = state.copyWith(
            currentFen: _position.fen,
            currentMoveIndex: newIndex,
            lastMove: move,
            state: PuzzleState.playing,
            validMoves: _convertToValidMoves(_position.legalMoves),
            clearFeedback: true,
            clearMarker: true,
          );
        }
      } catch (e) {
        debugPrint('Error making opponent move: $e');
        state = state.copyWith(
          feedback: 'Puzzle error',
          state: PuzzleState.ready,
        );
      }
    }
  }

  void resetPuzzle() {
    final puzzle = state.puzzle;
    if (puzzle != null) {
      loadPuzzle(puzzle);
    }
  }

  void showHint() {
    final puzzle = state.puzzle;
    if (puzzle == null || state.currentMoveIndex >= puzzle.solution.length) {
      return;
    }

    // Don't show hint if puzzle is not in playing state
    if (state.state != PuzzleState.playing) return;

    final nextMove = puzzle.solution[state.currentMoveIndex];
    final move = _parseUciMove(nextMove);

    if (move != null) {
      // Show marker on the piece to move (from square)
      state = state.copyWith(
        markerType: PuzzleMarkerType.hint,
        markerSquare: move.from,
        hintsUsed: state.hintsUsed + 1,
      );

      // Clear hint marker after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && state.markerType == PuzzleMarkerType.hint) {
          state = state.copyWith(clearMarker: true);
        }
      });
    }
  }

  NormalMove? _parseUciMove(String uci) {
    if (uci.length < 4) return null;

    try {
      final from = Square.fromName(uci.substring(0, 2));
      final to = Square.fromName(uci.substring(2, 4));

      Role? promotion;
      if (uci.length > 4) {
        switch (uci[4].toLowerCase()) {
          case 'q':
            promotion = Role.queen;
            break;
          case 'r':
            promotion = Role.rook;
            break;
          case 'b':
            promotion = Role.bishop;
            break;
          case 'n':
            promotion = Role.knight;
            break;
        }
      }

      return NormalMove(from: from, to: to, promotion: promotion);
    } catch (e) {
      return null;
    }
  }

  ValidMoves _convertToValidMoves(IMap<Square, SquareSet> dartchessMoves) {
    final Map<Square, ISet<Square>> result = {};
    for (final entry in dartchessMoves.entries) {
      final squares = <Square>[];
      for (final sq in entry.value.squares) {
        squares.add(sq);
      }
      result[entry.key] = ISet(squares);
    }

    // Add standard castling destinations for the king
    // dartchess returns rook squares (h1/a1), but users expect g1/c1
    final king = _position.board.kingOf(_position.turn);
    if (king != null && result.containsKey(king)) {
      final kingMoves = result[king]!.toSet();
      final Set<Square> additionalMoves = {};

      // Check if king can castle kingside (add g1/g8)
      final kingsideRook = _position.turn == Side.white ? Square.h1 : Square.h8;
      final kingsideDest = _position.turn == Side.white ? Square.g1 : Square.g8;
      if (kingMoves.contains(kingsideRook)) {
        additionalMoves.add(kingsideDest);
      }

      // Check if king can castle queenside (add c1/c8)
      final queensideRook = _position.turn == Side.white ? Square.a1 : Square.a8;
      final queensideDest = _position.turn == Side.white ? Square.c1 : Square.c8;
      if (kingMoves.contains(queensideRook)) {
        additionalMoves.add(queensideDest);
      }

      if (additionalMoves.isNotEmpty) {
        result[king] = ISet({...kingMoves, ...additionalMoves});
      }
    }

    return IMap(result);
  }

  Side get sideToMove => _position.turn;

  void flipBoard() {
    state = state.copyWith(
      orientation: state.orientation == Side.white ? Side.black : Side.white,
    );
  }
}

// Provider
final puzzleSolveProvider =
    StateNotifierProvider<PuzzleSolveNotifier, PuzzleSolveState>((ref) {
  final gamificationNotifier = ref.read(gamificationProvider.notifier);
  return PuzzleSolveNotifier(gamificationNotifier);
});
