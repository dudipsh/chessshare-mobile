import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' show NormalMove, Side;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/board_settings_provider.dart';
import '../providers/captured_pieces_provider.dart';
import 'board_settings_factory.dart';
import 'captured_pieces_display.dart';

/// A unified shell component that wraps chess boards with consistent
/// top/bottom slots for captured pieces display.
///
/// This ensures visual consistency across all screens that display a chess board:
/// - Study
/// - My Games (Review, Practice, Play vs Stockfish)
/// - Puzzles
/// - Analysis
///
/// The shell provides:
/// - Fixed height top slot (opponent's captured pieces / pieces they lost)
/// - The chess board itself
/// - Fixed height bottom slot (player's captured pieces / pieces they took)
///
/// Orientation-aware: When the board is flipped, captured pieces positions adjust
/// accordingly.
class ChessBoardShell extends ConsumerWidget {
  /// The chess board widget to display
  final Widget board;

  /// The current board orientation (which side is at the bottom)
  final Side orientation;

  /// The current FEN string (used to calculate captured pieces)
  final String fen;

  /// Whether to show captured pieces (default: true)
  final bool showCapturedPieces;

  /// Height of the captured pieces slots
  final double slotHeight;

  /// Optional overlay widgets to display on top of the board
  final List<Widget>? overlays;

  /// Padding around the board
  final EdgeInsets padding;

  const ChessBoardShell({
    super.key,
    required this.board,
    required this.orientation,
    required this.fen,
    this.showCapturedPieces = true,
    this.slotHeight = 24,
    this.overlays,
    this.padding = const EdgeInsets.all(8.0),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Update captured pieces when FEN changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(capturedPiecesProvider.notifier).updateFromFen(fen);
    });

    // When orientation is white (white at bottom):
    // - Top slot shows pieces captured by black (white pieces that were taken)
    // - Bottom slot shows pieces captured by white (black pieces that were taken)
    //
    // When orientation is black (black at bottom):
    // - Top slot shows pieces captured by white (black pieces that were taken)
    // - Bottom slot shows pieces captured by black (white pieces that were taken)
    final topShowsCapturedByWhite = orientation == Side.black;
    final bottomShowsCapturedByWhite = orientation == Side.white;

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top slot - opponent's captured pieces (pieces they lost)
          SizedBox(
            height: slotHeight,
            child: showCapturedPieces
                ? CapturedPiecesDisplay(
                    showCapturedByWhite: topShowsCapturedByWhite,
                  )
                : null,
          ),
          // Board with optional overlays
          Stack(
            children: [
              board,
              if (overlays != null) ...overlays!,
            ],
          ),
          // Bottom slot - player's captured pieces (pieces they took)
          SizedBox(
            height: slotHeight,
            child: showCapturedPieces
                ? CapturedPiecesDisplay(
                    showCapturedByWhite: bottomShowsCapturedByWhite,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// A builder for creating interactive chess boards with the shell.
///
/// This provides a convenient way to create a complete board setup
/// with consistent settings and captured pieces display.
class ChessBoardShellBuilder extends ConsumerWidget {
  /// Board size (width/height)
  final double size;

  /// Current FEN position
  final String fen;

  /// Board orientation
  final Side orientation;

  /// Last move to highlight
  final NormalMove? lastMove;

  /// Game data for interactive boards (null for fixed/view-only boards)
  final GameData? game;

  /// Whether to show captured pieces
  final bool showCapturedPieces;

  /// Optional overlays (markers, hints, etc.)
  final List<Widget>? overlays;

  /// Padding around the board
  final EdgeInsets padding;

  const ChessBoardShellBuilder({
    super.key,
    required this.size,
    required this.fen,
    required this.orientation,
    this.lastMove,
    this.game,
    this.showCapturedPieces = true,
    this.overlays,
    this.padding = const EdgeInsets.all(8.0),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardSettings = ref.watch(boardSettingsProvider);
    final settings = BoardSettingsFactory.create(boardSettings: boardSettings);

    final Widget chessBoard;
    if (game != null) {
      chessBoard = Chessboard(
        size: size,
        settings: settings,
        orientation: orientation,
        fen: fen,
        lastMove: lastMove,
        game: game!,
      );
    } else {
      chessBoard = Chessboard.fixed(
        size: size,
        settings: settings,
        orientation: orientation,
        fen: fen,
        lastMove: lastMove,
      );
    }

    return ChessBoardShell(
      board: chessBoard,
      orientation: orientation,
      fen: fen,
      showCapturedPieces: showCapturedPieces,
      overlays: overlays,
      padding: padding,
    );
  }
}
