import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/audio_service.dart';
import '../../gamification/models/xp_models.dart';
import '../../gamification/providers/gamification_provider.dart';
import '../models/study_board.dart';
import 'study_castling_utils.dart';
import 'study_move_utils.dart';
import 'study_state.dart';

export 'study_state.dart' show StudyBoardState, StudyState, MarkerType;
export 'study_move_utils.dart' show MoveInfo;

class StudyBoardNotifier extends StateNotifier<StudyBoardState> {
  final AudioService _audioService;
  final GamificationNotifier? _gamificationNotifier;
  Chess _position = Chess.initial;

  StudyBoardNotifier(this._audioService, this._gamificationNotifier)
      : super(const StudyBoardState());

  void loadBoard(StudyBoard board) {
    if (board.variations.isEmpty) {
      state = StudyBoardState(
        board: board,
        state: StudyState.ready,
        feedback: 'No variations in this study',
      );
      return;
    }

    state = state.copyWith(board: board);
    loadVariation(0);
  }

  void loadVariation(int index) {
    final board = state.board;
    if (board == null || index < 0 || index >= board.variations.length) return;

    final variation = board.variations[index];
    _loadVariationData(variation, index);
  }

  void _loadVariationData(StudyVariation variation, int index) {
    try {
      final startingFen = variation.startingFen ?? kInitialFEN;
      _position = Chess.fromSetup(Setup.parseFen(startingFen));

      final expectedMoves = StudyMoveUtils.parsePgnToMoves(variation.pgn, startingFen);
      final playerColor = variation.playerColor?.toLowerCase() == 'black'
          ? Side.black
          : Side.white;

      state = StudyBoardState(
        board: state.board,
        currentVariation: variation,
        currentVariationIndex: index,
        currentFen: startingFen,
        moveIndex: 0,
        expectedMoves: expectedMoves,
        state: StudyState.playing,
        orientation: playerColor,
        validMoves: StudyMoveUtils.getValidMoves(_position),
        hintsUsed: 0,
        mistakesMade: 0,
        completedMoves: 0,
      );

      // If it's computer's turn first, make the move automatically
      if (!state.isUserTurn && expectedMoves.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), _makeComputerMove);
      }
    } catch (e) {
      debugPrint('Error loading variation: $e');
      state = state.copyWith(
        state: StudyState.ready,
        feedback: 'Error loading variation',
      );
    }
  }

  void makeMove(NormalMove move) {
    if (state.state != StudyState.playing && state.state != StudyState.correct) {
      return;
    }
    if (!state.isUserTurn) return;

    final originalFen = state.currentFen;
    final king = _position.board.kingOf(_position.turn);
    final castlingResult = StudyCastlingUtils.convertCastlingMove(move, king);
    final actualMove = castlingResult?.actualMove ?? move;
    // For castling, marker should be on king's final position, not rook's
    final markerSquare = castlingResult?.markerPosition ?? move.to;

    final expectedSan = state.moveIndex < state.expectedMoves.length
        ? state.expectedMoves[state.moveIndex]
        : null;

    if (expectedSan == null) {
      _executeMove(actualMove, markerSquare: markerSquare);
      return;
    }

    final (_, userSan) = _position.makeSan(actualMove);
    final normalizedExpected = expectedSan.replaceAll('+', '').replaceAll('#', '');
    final normalizedUser = userSan.replaceAll('+', '').replaceAll('#', '');

    if (normalizedUser == normalizedExpected) {
      _executeMove(actualMove, markerSquare: markerSquare);
    } else {
      _handleWrongMove(actualMove, originalFen);
    }
  }

  void _executeMove(NormalMove move, {Square? markerSquare}) {
    final moveInfo = StudyMoveUtils.getMoveInfo(move, _position);
    _position = _position.play(move) as Chess;

    _audioService.playMoveWithHaptic(
      isCapture: moveInfo.isCapture,
      isCheck: moveInfo.isCheck,
      isCastle: moveInfo.isCastle,
      isCheckmate: moveInfo.isCheckmate,
    );

    final newMoveIndex = state.moveIndex + 1;
    final isComplete = newMoveIndex >= state.expectedMoves.length;
    // Use provided markerSquare (for castling) or default to move.to
    final effectiveMarkerSquare = markerSquare ?? move.to;

    if (isComplete) {
      _audioService.playEndLevel();
      _audioService.vibrate();

      state = state.copyWith(
        currentFen: _position.fen,
        moveIndex: newMoveIndex,
        lastMove: move,
        state: StudyState.completed,
        validMoves: IMap(),
        feedback: 'Line completed!',
        markerType: MarkerType.valid,
        markerSquare: effectiveMarkerSquare,
        completedMoves: state.completedMoves + 1,
      );

      _gamificationNotifier?.awardXp(
        XpEventType.studyLineComplete,
        relatedId: state.currentVariation?.id,
      );
    } else {
      state = state.copyWith(
        currentFen: _position.fen,
        moveIndex: newMoveIndex,
        lastMove: move,
        state: StudyState.correct,
        feedback: 'Correct!',
        markerType: MarkerType.valid,
        markerSquare: effectiveMarkerSquare,
        completedMoves: state.completedMoves + 1,
      );

      if (!state.isUserTurn) {
        Future.delayed(const Duration(milliseconds: 600), () {
          _clearMarker();
          Future.delayed(const Duration(milliseconds: 200), _makeComputerMove);
        });
      } else {
        Future.delayed(const Duration(milliseconds: 800), _clearMarker);
      }
    }
  }

  void _handleWrongMove(NormalMove move, String originalFen) {
    _audioService.playIllegal();
    _audioService.vibrate();

    try {
      _position = _position.play(move) as Chess;
    } catch (e) {
      // Move failed
    }

    state = state.copyWith(
      currentFen: _position.fen,
      lastMove: move,
      state: StudyState.incorrect,
      feedback: 'Try again',
      markerType: MarkerType.invalid,
      markerSquare: move.to,
      mistakesMade: state.mistakesMade + 1,
      validMoves: IMap(),
    );

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        try {
          _position = Chess.fromSetup(Setup.parseFen(originalFen));
        } catch (e) {
          debugPrint('Error restoring position: $e');
        }

        state = state.copyWith(
          currentFen: originalFen,
          state: StudyState.playing,
          validMoves: StudyMoveUtils.getValidMoves(_position),
          clearFeedback: true,
          clearMarker: true,
          clearLastMove: true,
        );
      }
    });
  }

  void _makeComputerMove() {
    if (state.moveIndex >= state.expectedMoves.length) return;
    if (state.isUserTurn) return;

    final san = state.expectedMoves[state.moveIndex];

    try {
      final move = _position.parseSan(san);
      if (move != null && move is NormalMove) {
        final moveInfo = StudyMoveUtils.getMoveInfo(move, _position);
        _position = _position.play(move) as Chess;

        _audioService.playMoveWithHaptic(
          isCapture: moveInfo.isCapture,
          isCheck: moveInfo.isCheck,
          isCastle: moveInfo.isCastle,
          isCheckmate: moveInfo.isCheckmate,
        );

        final newMoveIndex = state.moveIndex + 1;
        final isComplete = newMoveIndex >= state.expectedMoves.length;

        if (isComplete) {
          _audioService.playEndLevel();
          state = state.copyWith(
            currentFen: _position.fen,
            moveIndex: newMoveIndex,
            lastMove: move,
            state: StudyState.completed,
            validMoves: IMap(),
            feedback: 'Line completed!',
          );
        } else {
          state = state.copyWith(
            currentFen: _position.fen,
            moveIndex: newMoveIndex,
            lastMove: move,
            state: StudyState.playing,
            validMoves: StudyMoveUtils.getValidMoves(_position),
            clearFeedback: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Error making computer move: $e');
    }
  }

  void _clearMarker() {
    if (mounted) {
      state = state.copyWith(clearMarker: true);
    }
  }

  void showHint() {
    if (state.moveIndex >= state.expectedMoves.length) return;

    final san = state.expectedMoves[state.moveIndex];

    try {
      final move = _position.parseSan(san);
      if (move != null && move is NormalMove) {
        _audioService.vibrate();

        state = state.copyWith(
          feedback: 'Hint: Move from ${move.from.name}',
          markerType: MarkerType.hint,
          markerSquare: move.from,
          hintsUsed: state.hintsUsed + 1,
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            state = state.copyWith(clearFeedback: true, clearMarker: true);
          }
        });
      }
    } catch (e) {
      debugPrint('Error showing hint: $e');
    }
  }

  void flipBoard() {
    state = state.copyWith(
      orientation: state.orientation == Side.white ? Side.black : Side.white,
    );
  }

  void resetVariation() {
    final variation = state.currentVariation;
    if (variation != null) {
      _loadVariationData(variation, state.currentVariationIndex);
    }
  }

  void nextVariation() {
    final board = state.board;
    if (board == null) return;
    final nextIndex = state.currentVariationIndex + 1;
    if (nextIndex < board.variations.length) {
      loadVariation(nextIndex);
    }
  }

  void previousVariation() {
    final prevIndex = state.currentVariationIndex - 1;
    if (prevIndex >= 0) {
      loadVariation(prevIndex);
    }
  }

  void goBack() {
    if (state.moveIndex <= 0) return;
    _replayToMoveIndex(state.moveIndex - 1);
  }

  void goForward() {
    if (state.moveIndex >= state.expectedMoves.length) return;

    final san = state.expectedMoves[state.moveIndex];
    try {
      final move = _position.parseSan(san);
      if (move != null && move is NormalMove) {
        final moveInfo = StudyMoveUtils.getMoveInfo(move, _position);
        _position = _position.play(move) as Chess;

        _audioService.playMoveWithHaptic(
          isCapture: moveInfo.isCapture,
          isCheck: moveInfo.isCheck,
          isCastle: moveInfo.isCastle,
          isCheckmate: moveInfo.isCheckmate,
        );

        final newMoveIndex = state.moveIndex + 1;
        final isComplete = newMoveIndex >= state.expectedMoves.length;

        state = state.copyWith(
          currentFen: _position.fen,
          moveIndex: newMoveIndex,
          lastMove: move,
          state: isComplete ? StudyState.completed : StudyState.playing,
          validMoves: isComplete ? IMap() : StudyMoveUtils.getValidMoves(_position),
        );
      }
    } catch (e) {
      debugPrint('Error going forward: $e');
    }
  }

  void _replayToMoveIndex(int targetIndex) {
    final variation = state.currentVariation;
    if (variation == null) return;

    try {
      final startingFen = variation.startingFen ?? kInitialFEN;
      _position = Chess.fromSetup(Setup.parseFen(startingFen));

      NormalMove? lastMove;
      for (int i = 0; i < targetIndex; i++) {
        if (i >= state.expectedMoves.length) break;
        final san = state.expectedMoves[i];
        final move = _position.parseSan(san);
        if (move != null && move is NormalMove) {
          _position = _position.play(move) as Chess;
          lastMove = move;
        }
      }

      state = state.copyWith(
        currentFen: _position.fen,
        moveIndex: targetIndex,
        lastMove: lastMove,
        state: StudyState.playing,
        validMoves: StudyMoveUtils.getValidMoves(_position),
        clearFeedback: true,
        clearMarker: true,
      );
    } catch (e) {
      debugPrint('Error replaying moves: $e');
    }
  }

  Side get sideToMove => _position.turn;
}

/// Provider for study board
final studyBoardProvider =
    StateNotifierProvider<StudyBoardNotifier, StudyBoardState>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  final gamificationNotifier = ref.read(gamificationProvider.notifier);
  return StudyBoardNotifier(audioService, gamificationNotifier);
});
