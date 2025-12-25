import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dartchess/dartchess.dart';
import 'package:chessground/chessground.dart' show ValidMoves;
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../../games/models/chess_game.dart';

class AnalysisState {
  final ChessGame? game;
  final List<NormalMove> moves; // Parsed moves from dartchess
  final List<String> sanMoves; // SAN notation
  final int currentMoveIndex; // -1 = starting position
  final String currentFen;
  final NormalMove? lastMove;
  final Side orientation;
  final bool isLoading;
  final String? error;
  final ValidMoves validMoves; // chessground's IMap<Square, ISet<Square>>

  AnalysisState({
    this.game,
    this.moves = const [],
    this.sanMoves = const [],
    this.currentMoveIndex = -1,
    this.currentFen = kInitialFEN,
    this.lastMove,
    this.orientation = Side.white,
    this.isLoading = false,
    this.error,
    ValidMoves? validMoves,
  }) : validMoves = validMoves ?? IMap();

  AnalysisState copyWith({
    ChessGame? game,
    List<NormalMove>? moves,
    List<String>? sanMoves,
    int? currentMoveIndex,
    String? currentFen,
    NormalMove? lastMove,
    Side? orientation,
    bool? isLoading,
    String? error,
    ValidMoves? validMoves,
    bool clearLastMove = false,
  }) {
    return AnalysisState(
      game: game ?? this.game,
      moves: moves ?? this.moves,
      sanMoves: sanMoves ?? this.sanMoves,
      currentMoveIndex: currentMoveIndex ?? this.currentMoveIndex,
      currentFen: currentFen ?? this.currentFen,
      lastMove: clearLastMove ? null : (lastMove ?? this.lastMove),
      orientation: orientation ?? this.orientation,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      validMoves: validMoves ?? this.validMoves,
    );
  }

  bool get isAtStart => currentMoveIndex == -1;
  bool get isAtEnd => currentMoveIndex == moves.length - 1;
  bool get canGoBack => currentMoveIndex > -1;
  bool get canGoForward => currentMoveIndex < moves.length - 1;

  String get currentMoveDisplay {
    if (currentMoveIndex == -1) return 'Start';
    final moveNum = (currentMoveIndex ~/ 2) + 1;
    final isWhite = currentMoveIndex % 2 == 0;
    return '$moveNum${isWhite ? '.' : '...'} ${sanMoves[currentMoveIndex]}';
  }
}

class AnalysisNotifier extends StateNotifier<AnalysisState> {
  Chess _position = Chess.initial;

  AnalysisNotifier() : super(AnalysisState());

  void loadGame(ChessGame game) {
    state = state.copyWith(isLoading: true, error: null);

    try {
      _position = Chess.initial;

      // Parse PGN
      final pgnGame = PgnGame.parsePgn(game.pgn);
      final moves = <NormalMove>[];
      final sanMoves = <String>[];

      // Get moves from PGN
      Chess pos = Chess.initial;
      for (final node in pgnGame.moves.mainline()) {
        final san = node.san;
        if (san != null) {
          final move = pos.parseSan(san);
          if (move != null && move is NormalMove) {
            moves.add(move);
            sanMoves.add(san);
            pos = pos.play(move) as Chess;
          }
        }
      }

      // Determine orientation based on player color
      final orientation =
          game.playerColor == 'black' ? Side.black : Side.white;

      state = AnalysisState(
        game: game,
        moves: moves,
        sanMoves: sanMoves,
        currentMoveIndex: -1,
        currentFen: _position.fen,
        orientation: orientation,
        isLoading: false,
        validMoves: _convertToValidMoves(_position.legalMoves),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load game: ${e.toString()}',
      );
    }
  }

  void goToMove(int index) {
    if (index < -1 || index >= state.moves.length) return;

    _position = Chess.initial;
    NormalMove? lastMove;

    // Replay moves up to index
    for (var i = 0; i <= index; i++) {
      final move = state.moves[i];
      _position = _position.play(move) as Chess;
      if (i == index) {
        lastMove = move;
      }
    }

    state = state.copyWith(
      currentMoveIndex: index,
      currentFen: _position.fen,
      lastMove: lastMove,
      clearLastMove: index == -1,
      validMoves: _convertToValidMoves(_position.legalMoves),
    );
  }

  void goToStart() {
    goToMove(-1);
  }

  void goToEnd() {
    goToMove(state.moves.length - 1);
  }

  void goBack() {
    if (state.canGoBack) {
      goToMove(state.currentMoveIndex - 1);
    }
  }

  void goForward() {
    if (state.canGoForward) {
      goToMove(state.currentMoveIndex + 1);
    }
  }

  void flipBoard() {
    state = state.copyWith(
      orientation: state.orientation == Side.white ? Side.black : Side.white,
    );
  }

  void onUserMove(NormalMove move, {bool? isDrop}) {
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

    // Check if it's a valid move using legalMoves map
    final validDests = _position.legalMoves[actualMove.from];
    final isLegal = validDests != null && validDests.has(actualMove.to);

    if (isLegal) {
      final (_, san) = _position.makeSan(actualMove);
      _position = _position.play(actualMove) as Chess;

      // If we're at the end of the current line, just append
      if (state.isAtEnd) {
        final newMoves = [...state.moves, move];
        final List<String> newSanMoves = [...state.sanMoves, san];

        state = state.copyWith(
          moves: newMoves,
          sanMoves: newSanMoves,
          currentMoveIndex: newMoves.length - 1,
          currentFen: _position.fen,
          lastMove: move,
          validMoves: _convertToValidMoves(_position.legalMoves),
        );
      } else {
        // If we're in the middle, create a new branch by truncating and appending
        final newMoves = [...state.moves.sublist(0, state.currentMoveIndex + 1), move];
        final List<String> newSanMoves = [...state.sanMoves.sublist(0, state.currentMoveIndex + 1), san];

        state = state.copyWith(
          moves: newMoves,
          sanMoves: newSanMoves,
          currentMoveIndex: newMoves.length - 1,
          currentFen: _position.fen,
          lastMove: move,
          validMoves: _convertToValidMoves(_position.legalMoves),
        );
      }
    }
  }

  /// Convert dartchess SquareSet to chessground ISet<Square>
  /// Also adds standard castling destinations (g1/c1, g8/c8)
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

  void clear() {
    _position = Chess.initial;
    state = AnalysisState();
  }
}

// Providers
final analysisProvider =
    StateNotifierProvider<AnalysisNotifier, AnalysisState>((ref) {
  return AnalysisNotifier();
});

// Convenience providers
final currentFenProvider = Provider<String>((ref) {
  return ref.watch(analysisProvider).currentFen;
});

final currentMoveIndexProvider = Provider<int>((ref) {
  return ref.watch(analysisProvider).currentMoveIndex;
});

final movesListProvider = Provider<List<String>>((ref) {
  return ref.watch(analysisProvider).sanMoves;
});
