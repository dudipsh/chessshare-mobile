import 'package:dartchess/dartchess.dart';
import 'package:chessground/chessground.dart' show ValidMoves;
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

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
