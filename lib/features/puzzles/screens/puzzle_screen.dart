import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/puzzle.dart';
import '../providers/puzzle_provider.dart';
import 'puzzle/puzzle_action_buttons.dart';
import 'puzzle/puzzle_board_settings.dart';
import 'puzzle/puzzle_feedback.dart';
import 'puzzle/puzzle_info_bar.dart';
import 'puzzle/puzzle_marker_painter.dart';

class PuzzleScreen extends ConsumerStatefulWidget {
  final Puzzle puzzle;

  const PuzzleScreen({super.key, required this.puzzle});

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  bool _loadAttempted = false;

  @override
  void initState() {
    super.initState();
    // Load puzzle once on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_loadAttempted) {
        _loadAttempted = true;
        ref.read(puzzleSolveProvider.notifier).loadPuzzle(widget.puzzle);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final puzzleState = ref.watch(puzzleSolveProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth - 16;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.puzzle.theme.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: () => ref.read(puzzleSolveProvider.notifier).showHint(),
            tooltip: 'Hint',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(puzzleSolveProvider.notifier).resetPuzzle(),
            tooltip: 'Reset',
          ),
        ],
      ),
      body: Column(
        children: [
          PuzzleInfoBar(sideToMove: widget.puzzle.sideToMove, rating: widget.puzzle.rating),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Stack(
              children: [
                _buildChessboard(ref, puzzleState, boardSize),
                if (puzzleState.markerType != PuzzleMarkerType.none && puzzleState.markerSquare != null)
                  PuzzleMarkerOverlay(
                    markerType: puzzleState.markerType,
                    markerSquare: puzzleState.markerSquare!,
                    orientation: puzzleState.orientation,
                    boardSize: boardSize,
                  ),
              ],
            ),
          ),
          if (puzzleState.feedback != null)
            PuzzleFeedback(feedback: puzzleState.feedback!, state: puzzleState.state),
          PuzzleInstructions(state: puzzleState.state),
          const Spacer(),
          if (puzzleState.state == PuzzleState.completed)
            PuzzleActionButtons(
              onTryAgain: () => ref.read(puzzleSolveProvider.notifier).resetPuzzle(),
              onDone: () => Navigator.pop(context),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildChessboard(WidgetRef ref, PuzzleSolveState state, double boardSize) {
    final notifier = ref.read(puzzleSolveProvider.notifier);
    final isPlayable = state.state == PuzzleState.playing;

    if (isPlayable) {
      return Chessboard(
        size: boardSize,
        settings: buildPuzzleBoardSettings(),
        orientation: state.orientation,
        fen: state.currentFen,
        lastMove: state.lastMove,
        game: GameData(
          playerSide: state.orientation == Side.white ? PlayerSide.white : PlayerSide.black,
          sideToMove: notifier.sideToMove,
          validMoves: state.validMoves,
          promotionMove: null,
          onMove: (move, {isDrop}) => notifier.makeMove(move),
          onPromotionSelection: (role) {},
        ),
      );
    } else {
      return Chessboard.fixed(
        size: boardSize,
        settings: buildPuzzleBoardSettings(),
        orientation: state.orientation,
        fen: state.currentFen,
        lastMove: state.lastMove,
      );
    }
  }
}
