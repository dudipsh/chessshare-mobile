import 'package:dartchess/dartchess.dart';
import 'package:chessground/chessground.dart' show ValidMoves;
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

import '../../../core/services/audio_service.dart';
import '../../gamification/models/xp_models.dart';
import '../../gamification/providers/gamification_provider.dart';
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
    // In study mode, moves alternate, starting with the first move
    // If playerColor is white, user plays on even indices (0, 2, 4...)
    // If playerColor is black, user plays on odd indices (1, 3, 5...)
    if (orientation == Side.white) {
      return moveIndex % 2 == 0;
    } else {
      return moveIndex % 2 == 1;
    }
  }
}

class StudyBoardNotifier extends StateNotifier<StudyBoardState> {
  final AudioService _audioService;
  final GamificationNotifier? _gamificationNotifier;
  Chess _position = Chess.initial;

  StudyBoardNotifier(this._audioService, this._gamificationNotifier) : super(const StudyBoardState());

  /// Load a board and start with the first variation
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

  /// Load a specific variation by index
  void loadVariation(int index) {
    final board = state.board;
    if (board == null || index < 0 || index >= board.variations.length) return;

    final variation = board.variations[index];
    _loadVariationData(variation, index);
  }

  void _loadVariationData(StudyVariation variation, int index) {
    try {
      // Parse starting FEN
      final startingFen = variation.startingFen ?? kInitialFEN;
      _position = Chess.fromSetup(Setup.parseFen(startingFen));

      // Parse PGN to get expected moves
      final expectedMoves = _parsePgnToMoves(variation.pgn, startingFen);

      // Determine player color (orientation)
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
        validMoves: _getValidMoves(),
        hintsUsed: 0,
        mistakesMade: 0,
        completedMoves: 0,
      );

      // If it's computer's turn first, make the move automatically
      if (!state.isUserTurn && expectedMoves.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _makeComputerMove();
        });
      }
    } catch (e) {
      debugPrint('Error loading variation: $e');
      state = state.copyWith(
        state: StudyState.ready,
        feedback: 'Error loading variation',
      );
    }
  }

  /// Parse PGN string to list of SAN moves
  List<String> _parsePgnToMoves(String pgn, String startingFen) {
    if (pgn.isEmpty) return [];

    try {
      // Create a temporary chess position to parse moves
      final tempChess = Chess.fromSetup(Setup.parseFen(startingFen));
      final moves = <String>[];

      // Clean PGN: remove comments {}, annotations, and move numbers
      String cleanPgn = pgn
          .replaceAll(RegExp(r'\{[^}]*\}'), '') // Remove comments
          .replaceAll(RegExp(r'\([^)]*\)'), '') // Remove variations
          .replaceAll(RegExp(r'\$\d+'), '')     // Remove NAGs like $1, $2
          .replaceAll(RegExp(r'\d+\.+'), '')    // Remove move numbers
          .replaceAll(RegExp(r'[!?]+'), '')     // Remove annotations
          .replaceAll(RegExp(r'1-0|0-1|1/2-1/2|\*'), '') // Remove results
          .trim();

      // Split into tokens
      final tokens = cleanPgn.split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();

      Chess current = tempChess;
      for (final token in tokens) {
        try {
          // Try to parse as a move
          final move = current.parseSan(token);
          if (move != null) {
            moves.add(token);
            current = current.play(move) as Chess;
          }
        } catch (e) {
          // Skip invalid tokens
        }
      }

      return moves;
    } catch (e) {
      debugPrint('Error parsing PGN: $e');
      return [];
    }
  }

  /// Handle user making a move
  void makeMove(NormalMove move) {
    if (state.state != StudyState.playing && state.state != StudyState.correct) {
      return;
    }

    if (!state.isUserTurn) return;

    // Save original FEN before any move attempt
    final originalFen = state.currentFen;

    final expectedSan = state.expectedMoves.isNotEmpty && state.moveIndex < state.expectedMoves.length
        ? state.expectedMoves[state.moveIndex]
        : null;

    if (expectedSan == null) {
      // Free play after line is done
      _executeMove(move, isExpected: true);
      return;
    }

    // Get the SAN of the user's move
    final (_, userSan) = _position.makeSan(move);

    // Normalize both for comparison (remove + and # symbols)
    final normalizedExpected = expectedSan.replaceAll('+', '').replaceAll('#', '');
    final normalizedUser = userSan.replaceAll('+', '').replaceAll('#', '');

    if (normalizedUser == normalizedExpected) {
      // Correct move!
      _executeMove(move, isExpected: true);
    } else {
      // Wrong move - show the move, then revert
      _handleWrongMove(move, originalFen);
    }
  }

  void _executeMove(NormalMove move, {required bool isExpected}) {
    final moveInfo = _getMoveInfo(move);
    _position = _position.play(move) as Chess;

    // Play sound
    _audioService.playMoveSound(
      isCapture: moveInfo.isCapture,
      isCheck: moveInfo.isCheck,
      isCastle: moveInfo.isCastle,
      isCheckmate: moveInfo.isCheckmate,
    );

    // Haptic feedback
    Haptics.vibrate(HapticsType.light);

    final newMoveIndex = state.moveIndex + 1;
    final isComplete = newMoveIndex >= state.expectedMoves.length;

    if (isComplete) {
      // Line completed!
      _audioService.playEndLevel();
      Haptics.vibrate(HapticsType.success);

      state = state.copyWith(
        currentFen: _position.fen,
        moveIndex: newMoveIndex,
        lastMove: move,
        state: StudyState.completed,
        validMoves: IMap(),
        feedback: 'Line completed!',
        markerType: MarkerType.valid,
        markerSquare: move.to,
        completedMoves: state.completedMoves + 1,
      );

      // Award XP for completing a study line
      debugPrint('[StudyBoard] Line completed! Awarding XP...');
      if (_gamificationNotifier != null) {
        _gamificationNotifier!.awardXp(
          XpEventType.studyLineComplete,
          relatedId: state.currentVariation?.id,
        ).then((result) {
          debugPrint('[StudyBoard] XP awarded: ${result?.xpAwarded ?? 0}, leveledUp: ${result?.leveledUp ?? false}');
        });
      } else {
        debugPrint('[StudyBoard] WARNING: _gamificationNotifier is null!');
      }
    } else {
      // Show correct marker
      state = state.copyWith(
        currentFen: _position.fen,
        moveIndex: newMoveIndex,
        lastMove: move,
        state: StudyState.correct,
        feedback: 'Correct!',
        markerType: MarkerType.valid,
        markerSquare: move.to,
        completedMoves: state.completedMoves + 1,
      );

      // Schedule computer's reply
      if (!state.isUserTurn) {
        Future.delayed(const Duration(milliseconds: 600), () {
          _clearMarker();
          Future.delayed(const Duration(milliseconds: 200), () {
            _makeComputerMove();
          });
        });
      } else {
        // Clear marker after delay
        Future.delayed(const Duration(milliseconds: 800), () {
          _clearMarker();
        });
      }
    }
  }

  void _handleWrongMove(NormalMove move, String originalFen) {
    // Play wrong move sound
    _audioService.playIllegal();
    Haptics.vibrate(HapticsType.error);

    // Temporarily execute the move to show it on the board
    try {
      _position = _position.play(move) as Chess;
    } catch (e) {
      // Move failed, just show marker
    }

    // Show the wrong move on board, then revert
    state = state.copyWith(
      currentFen: _position.fen,
      lastMove: move,
      state: StudyState.incorrect,
      feedback: 'Try again',
      markerType: MarkerType.invalid,
      markerSquare: move.to,
      mistakesMade: state.mistakesMade + 1,
      validMoves: IMap(), // Disable moves while showing error
    );

    // After delay, revert to original position
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        // Restore original position
        try {
          _position = Chess.fromSetup(Setup.parseFen(originalFen));
        } catch (e) {
          debugPrint('Error restoring position: $e');
        }

        state = state.copyWith(
          currentFen: originalFen,
          state: StudyState.playing,
          validMoves: _getValidMoves(),
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
        final moveInfo = _getMoveInfo(move);
        _position = _position.play(move) as Chess;

        // Play sound
        _audioService.playMoveSound(
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
            validMoves: _getValidMoves(),
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

  /// Show hint for the current move
  void showHint() {
    if (state.moveIndex >= state.expectedMoves.length) return;

    final san = state.expectedMoves[state.moveIndex];

    try {
      final move = _position.parseSan(san);
      if (move != null && move is NormalMove) {
        Haptics.vibrate(HapticsType.light);

        state = state.copyWith(
          feedback: 'Hint: Move from ${move.from.name}',
          markerType: MarkerType.hint,
          markerSquare: move.from,
          hintsUsed: state.hintsUsed + 1,
        );

        // Clear hint after delay
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

  /// Flip board orientation
  void flipBoard() {
    state = state.copyWith(
      orientation: state.orientation == Side.white ? Side.black : Side.white,
    );
  }

  /// Reset current variation
  void resetVariation() {
    final variation = state.currentVariation;
    if (variation != null) {
      _loadVariationData(variation, state.currentVariationIndex);
    }
  }

  /// Go to next variation
  void nextVariation() {
    final board = state.board;
    if (board == null) return;

    final nextIndex = state.currentVariationIndex + 1;
    if (nextIndex < board.variations.length) {
      loadVariation(nextIndex);
    }
  }

  /// Go to previous variation
  void previousVariation() {
    final prevIndex = state.currentVariationIndex - 1;
    if (prevIndex >= 0) {
      loadVariation(prevIndex);
    }
  }

  /// Go back one move (for review)
  void goBack() {
    if (state.moveIndex <= 0) return;

    // Replay moves up to moveIndex - 1
    final targetMoveIndex = state.moveIndex - 1;
    _replayToMoveIndex(targetMoveIndex);
  }

  /// Go forward one move (for review)
  void goForward() {
    if (state.moveIndex >= state.expectedMoves.length) return;

    final san = state.expectedMoves[state.moveIndex];
    try {
      final move = _position.parseSan(san);
      if (move != null && move is NormalMove) {
        final moveInfo = _getMoveInfo(move);
        _position = _position.play(move) as Chess;

        _audioService.playMoveSound(
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
          validMoves: isComplete ? IMap() : _getValidMoves(),
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
        validMoves: _getValidMoves(),
        clearFeedback: true,
        clearMarker: true,
      );
    } catch (e) {
      debugPrint('Error replaying moves: $e');
    }
  }

  MoveInfo _getMoveInfo(NormalMove move) {
    final piece = _position.board.pieceAt(move.from);
    final capturedPiece = _position.board.pieceAt(move.to);

    // Check if it's castling (king moving 2 squares)
    final isCastle = piece?.role == Role.king &&
        (move.from.file - move.to.file).abs() == 2;

    // Make the move temporarily to check for check/checkmate
    final afterMove = _position.play(move) as Chess;
    final isCheck = afterMove.isCheck;
    final isCheckmate = afterMove.isCheckmate;

    return MoveInfo(
      isCapture: capturedPiece != null,
      isCheck: isCheck,
      isCastle: isCastle,
      isCheckmate: isCheckmate,
    );
  }

  ValidMoves _getValidMoves() {
    final Map<Square, ISet<Square>> result = {};
    for (final entry in _position.legalMoves.entries) {
      final squares = <Square>[];
      for (final sq in entry.value.squares) {
        squares.add(sq);
      }
      result[entry.key] = ISet(squares);
    }
    return IMap(result);
  }

  Side get sideToMove => _position.turn;
}

class MoveInfo {
  final bool isCapture;
  final bool isCheck;
  final bool isCastle;
  final bool isCheckmate;

  const MoveInfo({
    required this.isCapture,
    required this.isCheck,
    required this.isCastle,
    required this.isCheckmate,
  });
}

/// Provider for study board
final studyBoardProvider =
    StateNotifierProvider<StudyBoardNotifier, StudyBoardState>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  final gamificationNotifier = ref.read(gamificationProvider.notifier);
  return StudyBoardNotifier(audioService, gamificationNotifier);
});
