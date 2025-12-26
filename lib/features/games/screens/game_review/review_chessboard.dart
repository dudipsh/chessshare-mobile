import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' show NormalMove, Side;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/board_settings_provider.dart';
import '../../../../core/providers/captured_pieces_provider.dart';
import '../../../../core/widgets/board_settings_factory.dart';
import '../../../../core/widgets/chess_board_shell.dart';
import '../../providers/exploration_mode_provider.dart';
import '../../providers/game_review_provider.dart';

class ReviewChessboard extends ConsumerWidget {
  final GameReviewState state;
  final ExplorationState explorationState;
  final double boardSize;
  final Side orientation;
  final void Function(NormalMove move) onMove;

  const ReviewChessboard({
    super.key,
    required this.state,
    required this.explorationState,
    required this.boardSize,
    required this.orientation,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardSettings = ref.watch(boardSettingsProvider);
    final settings = BoardSettingsFactory.create(
      boardSettings: boardSettings,
      showLastMove: !explorationState.isExploring,
    );

    final fen = explorationState.isExploring ? explorationState.fen : state.fen;
    final validMoves = explorationState.validMoves;

    // Update captured pieces
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(capturedPiecesProvider.notifier).updateFromFen(fen);
    });

    final chessBoard = Chessboard(
      size: boardSize,
      settings: settings,
      orientation: orientation,
      fen: fen,
      lastMove: explorationState.isExploring ? null : state.lastMove,
      game: GameData(
        playerSide: PlayerSide.both,
        sideToMove: explorationState.sideToMove,
        validMoves: validMoves,
        promotionMove: null,
        onMove: (move, {isDrop}) => onMove(move),
        onPromotionSelection: (role) {},
      ),
    );

    return ChessBoardShell(
      board: chessBoard,
      orientation: orientation,
      fen: fen,
      showCapturedPieces: true,
      padding: EdgeInsets.zero,
    );
  }
}
