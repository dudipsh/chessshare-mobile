import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';

import '../../../app/theme/colors.dart';
import '../models/puzzle.dart';
import '../providers/puzzle_provider.dart';

class PuzzleScreen extends ConsumerWidget {
  final Puzzle puzzle;

  const PuzzleScreen({super.key, required this.puzzle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puzzleState = ref.watch(puzzleSolveProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Load puzzle on first build
    if (puzzleState.puzzle?.id != puzzle.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(puzzleSolveProvider.notifier).loadPuzzle(puzzle);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(puzzle.theme.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: () {
              ref.read(puzzleSolveProvider.notifier).showHint();
            },
            tooltip: 'Hint',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(puzzleSolveProvider.notifier).resetPuzzle();
            },
            tooltip: 'Reset',
          ),
        ],
      ),
      body: Column(
        children: [
          // Puzzle info
          _buildPuzzleInfo(context, puzzleState),

          // Chess board
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildChessboard(context, ref, puzzleState, screenWidth - 16),
          ),

          // Feedback
          if (puzzleState.feedback != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Text(
                puzzleState.feedback!,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getFeedbackColor(puzzleState.state),
                ),
              ),
            ),

          // Instructions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _getInstructions(puzzleState),
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const Spacer(),

          // Bottom buttons
          if (puzzleState.state == PuzzleState.completed)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref.read(puzzleSolveProvider.notifier).resetPuzzle();
                      },
                      child: const Text('Try Again'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildPuzzleInfo(BuildContext context, PuzzleSolveState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Side to move indicator
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: puzzle.sideToMove == Side.white
                  ? Colors.white
                  : Colors.grey.shade800,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${puzzle.sideToMove == Side.white ? "White" : "Black"} to move',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const Spacer(),
          // Rating
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${puzzle.rating}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChessboard(
    BuildContext context,
    WidgetRef ref,
    PuzzleSolveState state,
    double boardSize,
  ) {
    final notifier = ref.read(puzzleSolveProvider.notifier);
    final isPlayable = state.state == PuzzleState.playing;

    if (isPlayable) {
      return Chessboard(
        size: boardSize,
        settings: _buildBoardSettings(),
        orientation: state.orientation,
        fen: state.currentFen,
        lastMove: state.lastMove,
        game: GameData(
          playerSide: state.orientation == Side.white
              ? PlayerSide.white
              : PlayerSide.black,
          sideToMove: notifier.sideToMove,
          validMoves: state.validMoves,
          promotionMove: null,
          onMove: (move, {isDrop}) {
            notifier.makeMove(move);
          },
          onPromotionSelection: (role) {},
        ),
      );
    } else {
      return Chessboard.fixed(
        size: boardSize,
        settings: _buildBoardSettings(),
        orientation: state.orientation,
        fen: state.currentFen,
        lastMove: state.lastMove,
      );
    }
  }

  ChessboardSettings _buildBoardSettings() {
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

  Color _getFeedbackColor(PuzzleState state) {
    switch (state) {
      case PuzzleState.correct:
      case PuzzleState.completed:
        return AppColors.success;
      case PuzzleState.incorrect:
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  String _getInstructions(PuzzleSolveState state) {
    switch (state.state) {
      case PuzzleState.ready:
        return 'Loading puzzle...';
      case PuzzleState.playing:
        return 'Find the best move';
      case PuzzleState.correct:
        return 'Keep going!';
      case PuzzleState.incorrect:
        return 'That\'s not quite right. Try again!';
      case PuzzleState.completed:
        return 'Puzzle solved!';
    }
  }
}
