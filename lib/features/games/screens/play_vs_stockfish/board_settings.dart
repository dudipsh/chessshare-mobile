import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

ChessboardSettings buildChessboardSettings() {
  return ChessboardSettings(
    pieceAssets: PieceSet.merida.assets,
    colorScheme: ChessboardColorScheme(
      lightSquare: AppColors.lightSquare,
      darkSquare: AppColors.darkSquare,
      background: SolidColorChessboardBackground(
        lightSquare: AppColors.lightSquare,
        darkSquare: AppColors.darkSquare,
      ),
      whiteCoordBackground: SolidColorChessboardBackground(
        lightSquare: AppColors.lightSquare,
        darkSquare: AppColors.darkSquare,
        coordinates: true,
      ),
      blackCoordBackground: SolidColorChessboardBackground(
        lightSquare: AppColors.lightSquare,
        darkSquare: AppColors.darkSquare,
        coordinates: true,
        orientation: Side.black,
      ),
      lastMove: HighlightDetails(solidColor: AppColors.lastMove),
      selected: HighlightDetails(solidColor: AppColors.highlight),
      validMoves: Colors.black.withValues(alpha: 0.15),
      validPremoves: Colors.blue.withValues(alpha: 0.2),
    ),
    showValidMoves: true,
    showLastMove: true,
    animationDuration: const Duration(milliseconds: 150),
    dragFeedbackScale: 2.0,
    dragFeedbackOffset: const Offset(0, -1),
  );
}
