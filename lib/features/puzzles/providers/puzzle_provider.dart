import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../gamification/models/xp_models.dart';
import '../../gamification/providers/gamification_provider.dart';
import '../models/puzzle.dart';
import 'puzzle_castling_utils.dart';
import 'puzzle_move_utils.dart';
import 'puzzle_state.dart';

export 'puzzle_state.dart' show PuzzleSolveState, PuzzleMarkerType;

class PuzzleSolveNotifier extends StateNotifier<PuzzleSolveState> {
  final GamificationNotifier? _gamificationNotifier;
  Chess _position = Chess.initial;

  PuzzleSolveNotifier(this._gamificationNotifier) : super(const PuzzleSolveState());

  void loadPuzzle(Puzzle puzzle) {
    debugPrint('=== LOADING PUZZLE: ${puzzle.id} ===');
    debugPrint('Puzzle FEN: ${puzzle.fen}');
    debugPrint('Puzzle Solution: ${puzzle.solution}');
    debugPrint('Puzzle Rating: ${puzzle.rating}');
    debugPrint('Puzzle Theme: ${puzzle.theme}');

    try {
      _position = Chess.fromSetup(Setup.parseFen(puzzle.fen));

      if (!_validatePuzzleSolution(puzzle)) {
        state = state.copyWith(
          feedback: 'Invalid puzzle - please try another',
          state: PuzzleState.ready,
        );
        return;
      }

      state = PuzzleSolveState(
        puzzle: puzzle,
        currentFen: puzzle.fen,
        currentMoveIndex: 0,
        state: PuzzleState.playing,
        orientation: puzzle.sideToMove,
        validMoves: PuzzleMoveUtils.convertToValidMoves(_position.legalMoves, _position),
      );
    } catch (e) {
      debugPrint('Failed to load puzzle: $e');
      state = state.copyWith(
        feedback: 'Failed to load puzzle',
        state: PuzzleState.ready,
      );
    }
  }

  bool _validatePuzzleSolution(Puzzle puzzle) {
    debugPrint('Validating puzzle: FEN=${puzzle.fen}, Solution=${puzzle.solution}');

    if (puzzle.fen.isEmpty || puzzle.solution.isEmpty) {
      debugPrint('Validation failed: FEN or solution empty');
      return false;
    }

    try {
      Chess pos = Chess.fromSetup(Setup.parseFen(puzzle.fen));
      debugPrint('Position loaded successfully. Turn: ${pos.turn}');

      for (int i = 0; i < puzzle.solution.length; i++) {
        final moveStr = puzzle.solution[i];
        debugPrint('Validating move $i: $moveStr');

        var move = PuzzleMoveUtils.parseUciMove(moveStr);
        if (move == null) {
          debugPrint('Failed to parse move: $moveStr');
          return false;
        }

        // Convert UCI castling notation to dartchess format
        // UCI uses e1g1/e1c1 but dartchess expects e1h1/e1a1 (king to rook square)
        final king = pos.board.kingOf(pos.turn);
        final castling = PuzzleCastlingUtils.convertCastlingMove(move, king);
        if (castling != null) {
          move = castling.actualMove;
          debugPrint('Converted castling move to: ${move.from.name}${move.to.name}');
        }

        if (!pos.legalMoves.containsKey(move.from)) {
          debugPrint('Move from square ${move.from} not in legal moves. Legal: ${pos.legalMoves.keys}');
          return false;
        }

        final legalTargets = pos.legalMoves[move.from];
        if (legalTargets == null || !legalTargets.squares.contains(move.to)) {
          debugPrint('Move to square ${move.to} not legal from ${move.from}. Legal targets: ${legalTargets?.squares}');
          return false;
        }

        pos = pos.play(move) as Chess;
      }

      debugPrint('Puzzle validation passed!');
      return true;
    } catch (e) {
      debugPrint('Validation exception: $e');
      return false;
    }
  }

  void makeMove(NormalMove move) {
    final puzzle = state.puzzle;
    if (puzzle == null || state.state != PuzzleState.playing) return;

    final king = _position.board.kingOf(_position.turn);

    // Handle castling conversion
    final castling = PuzzleCastlingUtils.convertCastlingMove(move, king);
    final actualMove = castling?.actualMove ?? move;
    final displayMove = castling?.displayMove ?? move;
    final markerPosition = castling?.markerPosition ?? move.to;

    final uci = '${actualMove.from.name}${actualMove.to.name}${actualMove.promotion?.letter ?? ''}';

    if (puzzle.isCorrectMove(uci, state.currentMoveIndex)) {
      _handleCorrectMove(puzzle, actualMove, displayMove, markerPosition);
    } else {
      _handleWrongMove(move);
    }
  }

  void _handleCorrectMove(Puzzle puzzle, NormalMove actualMove, NormalMove displayMove, Square markerPosition) {
    _position = _position.play(actualMove) as Chess;
    final newIndex = state.currentMoveIndex + 1;

    if (newIndex >= puzzle.solution.length) {
      state = state.copyWith(
        currentFen: _position.fen,
        currentMoveIndex: newIndex,
        lastMove: displayMove,
        state: PuzzleState.completed,
        validMoves: IMap(),
        feedback: 'Excellent!',
        markerType: PuzzleMarkerType.correct,
        markerSquare: markerPosition,
      );

      _gamificationNotifier?.awardXp(XpEventType.puzzleSolve, relatedId: puzzle.id);
    } else {
      state = state.copyWith(
        currentFen: _position.fen,
        currentMoveIndex: newIndex,
        lastMove: displayMove,
        state: PuzzleState.correct,
        feedback: 'Correct!',
        markerType: PuzzleMarkerType.correct,
        markerSquare: markerPosition,
      );

      Future.delayed(const Duration(milliseconds: 400), _makeOpponentMove);
    }
  }

  void _handleWrongMove(NormalMove move) {
    final originalFen = state.currentFen;
    final tempPosition = _position.play(move) as Chess;

    state = state.copyWith(
      currentFen: tempPosition.fen,
      lastMove: move,
      state: PuzzleState.incorrect,
      feedback: 'Try again',
      markerType: PuzzleMarkerType.incorrect,
      markerSquare: move.to,
      validMoves: IMap(),
    );

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        state = state.copyWith(
          currentFen: originalFen,
          state: PuzzleState.playing,
          validMoves: PuzzleMoveUtils.convertToValidMoves(_position.legalMoves, _position),
          clearLastMove: true,
          clearFeedback: true,
          clearMarker: true,
        );
      }
    });
  }

  void _makeOpponentMove() {
    final puzzle = state.puzzle;
    if (puzzle == null || state.currentMoveIndex >= puzzle.solution.length) return;

    final move = PuzzleMoveUtils.parseUciMove(puzzle.solution[state.currentMoveIndex]);
    if (move == null) return;

    try {
      if (!_position.legalMoves.containsKey(move.from)) {
        state = state.copyWith(
          feedback: 'Puzzle error - invalid opponent move',
          state: PuzzleState.ready,
        );
        return;
      }

      _position = _position.play(move) as Chess;
      final newIndex = state.currentMoveIndex + 1;

      if (newIndex >= puzzle.solution.length) {
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
          validMoves: PuzzleMoveUtils.convertToValidMoves(_position.legalMoves, _position),
          clearFeedback: true,
          clearMarker: true,
        );
      }
    } catch (e) {
      debugPrint('Error making opponent move: $e');
      state = state.copyWith(feedback: 'Puzzle error', state: PuzzleState.ready);
    }
  }

  void resetPuzzle() {
    final puzzle = state.puzzle;
    if (puzzle != null) loadPuzzle(puzzle);
  }

  void showHint() {
    final puzzle = state.puzzle;
    if (puzzle == null || state.currentMoveIndex >= puzzle.solution.length) return;
    if (state.state != PuzzleState.playing) return;

    final move = PuzzleMoveUtils.parseUciMove(puzzle.solution[state.currentMoveIndex]);
    if (move != null) {
      state = state.copyWith(
        markerType: PuzzleMarkerType.hint,
        markerSquare: move.from,
        hintsUsed: state.hintsUsed + 1,
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && state.markerType == PuzzleMarkerType.hint) {
          state = state.copyWith(clearMarker: true);
        }
      });
    }
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
