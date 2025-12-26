import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../providers/board_settings_provider.dart';

/// Factory for creating consistent ChessboardSettings across all screens.
/// This eliminates code duplication and ensures visual consistency.
class BoardSettingsFactory {
  /// Creates ChessboardSettings from the current board settings state.
  ///
  /// [boardSettings] - The current board settings from the provider
  /// [showValidMoves] - Whether to show valid move indicators (default: true)
  /// [showLastMove] - Whether to highlight the last move (default: true)
  /// [animationDuration] - Duration of piece animations (default: 150ms)
  /// [dragFeedbackScale] - Scale of piece while dragging (default: 2.0)
  /// [dragFeedbackOffset] - Offset of piece while dragging (default: (0, -1))
  static ChessboardSettings create({
    required BoardSettingsState boardSettings,
    bool showValidMoves = true,
    bool showLastMove = true,
    Duration animationDuration = const Duration(milliseconds: 150),
    double dragFeedbackScale = 2.0,
    Offset dragFeedbackOffset = const Offset(0, -1),
  }) {
    final lightSquare = boardSettings.colorScheme.lightSquare;
    final darkSquare = boardSettings.colorScheme.darkSquare;
    final pieceAssets = boardSettings.pieceSet.pieceSet.assets;

    return ChessboardSettings(
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
      showValidMoves: showValidMoves,
      showLastMove: showLastMove,
      animationDuration: animationDuration,
      dragFeedbackScale: dragFeedbackScale,
      dragFeedbackOffset: dragFeedbackOffset,
    );
  }
}
