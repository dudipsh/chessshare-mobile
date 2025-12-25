import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' show NormalMove, Side;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/providers/board_settings_provider.dart';
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
    final lightSquare = boardSettings.colorScheme.lightSquare;
    final darkSquare = boardSettings.colorScheme.darkSquare;
    final pieceAssets = boardSettings.pieceSet.pieceSet.assets;

    final settings = ChessboardSettings(
      pieceAssets: pieceAssets,
      colorScheme: ChessboardColorScheme(
        lightSquare: lightSquare,
        darkSquare: darkSquare,
        background: SolidColorChessboardBackground(
          lightSquare: lightSquare,
          darkSquare: darkSquare,
        ),
        whiteCoordBackground: SolidColorChessboardBackground(
          lightSquare: lightSquare,
          darkSquare: darkSquare,
          coordinates: true,
        ),
        blackCoordBackground: SolidColorChessboardBackground(
          lightSquare: lightSquare,
          darkSquare: darkSquare,
          coordinates: true,
          orientation: Side.black,
        ),
        lastMove: HighlightDetails(solidColor: AppColors.lastMove),
        selected: HighlightDetails(solidColor: AppColors.highlight),
        validMoves: Colors.black.withValues(alpha: 0.15),
        validPremoves: Colors.blue.withValues(alpha: 0.2),
      ),
      showValidMoves: true,
      showLastMove: !explorationState.isExploring,
      animationDuration: const Duration(milliseconds: 150),
      dragFeedbackScale: 2.0,
      dragFeedbackOffset: const Offset(0, -1),
    );

    final fen = explorationState.isExploring ? explorationState.fen : state.fen;
    final validMoves = explorationState.validMoves;

    return Chessboard(
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
  }
}
