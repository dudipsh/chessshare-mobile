import 'package:dartchess/dartchess.dart';
import 'package:chessground/chessground.dart' show ValidMoves;
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../models/study_board.dart';

/// State for study board (playing a variation)
enum StudyState {
  loading,
  ready,
  playing,
  correct,
  incorrect,
  completed,
}

/// Marker types for visual feedback
enum MarkerType {
  none,
  valid,    // Green checkmark
  invalid,  // Red X
  hint,     // Blue hint circle
}

class StudyBoardState {
  final StudyBoard? board;
  final StudyVariation? currentVariation;
  final int currentVariationIndex;
  final String currentFen;
  final int moveIndex;
  final List<String> expectedMoves;  // SAN moves
  final StudyState state;
  final NormalMove? lastMove;
  final Side orientation;
  final ValidMoves validMoves;
  final String? feedback;
  final MarkerType markerType;
  final Square? markerSquare;
  final int hintsUsed;
  final int mistakesMade;
  final int completedMoves;

  const StudyBoardState({
    this.board,
    this.currentVariation,
    this.currentVariationIndex = 0,
    this.currentFen = kInitialFEN,
    this.moveIndex = 0,
    this.expectedMoves = const [],
    this.state = StudyState.loading,
    this.lastMove,
    this.orientation = Side.white,
    ValidMoves? validMoves,
    this.feedback,
    this.markerType = MarkerType.none,
    this.markerSquare,
    this.hintsUsed = 0,
    this.mistakesMade = 0,
    this.completedMoves = 0,
  }) : validMoves = validMoves ?? const IMapConst({});

  StudyBoardState copyWith({
    StudyBoard? board,
    StudyVariation? currentVariation,
    int? currentVariationIndex,
    String? currentFen,
    int? moveIndex,
    List<String>? expectedMoves,
    StudyState? state,
    NormalMove? lastMove,
    Side? orientation,
    ValidMoves? validMoves,
    String? feedback,
    MarkerType? markerType,
    Square? markerSquare,
    int? hintsUsed,
    int? mistakesMade,
    int? completedMoves,
    bool clearLastMove = false,
    bool clearFeedback = false,
    bool clearMarker = false,
  }) {
    return StudyBoardState(
      board: board ?? this.board,
      currentVariation: currentVariation ?? this.currentVariation,
      currentVariationIndex: currentVariationIndex ?? this.currentVariationIndex,
      currentFen: currentFen ?? this.currentFen,
      moveIndex: moveIndex ?? this.moveIndex,
      expectedMoves: expectedMoves ?? this.expectedMoves,
      state: state ?? this.state,
      lastMove: clearLastMove ? null : (lastMove ?? this.lastMove),
      orientation: orientation ?? this.orientation,
      validMoves: validMoves ?? this.validMoves,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      markerType: clearMarker ? MarkerType.none : (markerType ?? this.markerType),
      markerSquare: clearMarker ? null : (markerSquare ?? this.markerSquare),
      hintsUsed: hintsUsed ?? this.hintsUsed,
      mistakesMade: mistakesMade ?? this.mistakesMade,
      completedMoves: completedMoves ?? this.completedMoves,
    );
  }

  bool get isComplete => moveIndex >= expectedMoves.length;

  int get totalMoves => expectedMoves.length;

  double get progress => totalMoves > 0 ? moveIndex / totalMoves : 0;

  bool get isUserTurn {
    // User plays from the orientation side
    // If playerColor is white, user plays on even indices (0, 2, 4...)
    // If playerColor is black, user plays on odd indices (1, 3, 5...)
    if (orientation == Side.white) {
      return moveIndex % 2 == 0;
    } else {
      return moveIndex % 2 == 1;
    }
  }
}
