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

          // Chess board with marker overlay
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Stack(
              children: [
                _buildChessboard(context, ref, puzzleState, screenWidth - 16),
                // Marker overlay
                if (puzzleState.markerType != PuzzleMarkerType.none && puzzleState.markerSquare != null)
                  _buildMarkerOverlay(puzzleState, screenWidth - 16),
              ],
            ),
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

  Widget _buildMarkerOverlay(PuzzleSolveState state, double boardSize) {
    final squareSize = boardSize / 8;
    final square = state.markerSquare!;

    // Calculate position based on orientation
    int file = square.file;
    int rank = square.rank;

    double left;
    double top;

    if (state.orientation == Side.black) {
      // Black at bottom: h1 at bottom-left, a8 at top-right
      left = (7 - file) * squareSize;
      top = rank * squareSize;
    } else {
      // White at bottom: a1 at bottom-left, h8 at top-right
      left = file * squareSize;
      top = (7 - rank) * squareSize;
    }

    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: squareSize,
        height: squareSize,
        child: _buildMarkerIcon(state.markerType, squareSize),
      ),
    );
  }

  Widget _buildMarkerIcon(PuzzleMarkerType type, double size) {
    if (type == PuzzleMarkerType.none) {
      return const SizedBox.shrink();
    }

    // Position marker in top-right corner (Chess.com/web style)
    final markerSize = size * 0.4;

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.all(markerSize * 0.1),
        child: CustomPaint(
          size: Size(markerSize, markerSize),
          painter: _PuzzleMarkerPainter(type),
        ),
      ),
    );
  }
}

/// Custom painter for puzzle markers
class _PuzzleMarkerPainter extends CustomPainter {
  final PuzzleMarkerType type;

  _PuzzleMarkerPainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(center.dx, center.dy + 1.5), radius, shadowPaint);

    // Draw main circle
    Color bgColor;
    Color borderColor;

    switch (type) {
      case PuzzleMarkerType.correct:
        bgColor = const Color(0xFF22C55E); // Green
        borderColor = const Color(0xFF16A34A);
        break;
      case PuzzleMarkerType.incorrect:
        bgColor = const Color(0xFFEF4444); // Red
        borderColor = const Color(0xFFDC2626);
        break;
      case PuzzleMarkerType.hint:
        bgColor = const Color(0xFFFACC15); // Yellow
        borderColor = const Color(0xFFEAB308);
        break;
      case PuzzleMarkerType.none:
        return;
    }

    final bgPaint = Paint()..color = bgColor;
    canvas.drawCircle(center, radius, bgPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius, borderPaint);

    // Draw symbol
    final symbolPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (type) {
      case PuzzleMarkerType.correct:
        // Checkmark
        final path = Path();
        path.moveTo(center.dx - size.width * 0.22, center.dy);
        path.lineTo(center.dx - size.width * 0.05, center.dy + size.height * 0.15);
        path.lineTo(center.dx + size.width * 0.22, center.dy - size.height * 0.15);
        canvas.drawPath(path, symbolPaint);
        break;
      case PuzzleMarkerType.incorrect:
        // X mark
        final offset = size.width * 0.18;
        canvas.drawLine(
          Offset(center.dx - offset, center.dy - offset),
          Offset(center.dx + offset, center.dy + offset),
          symbolPaint,
        );
        canvas.drawLine(
          Offset(center.dx + offset, center.dy - offset),
          Offset(center.dx - offset, center.dy + offset),
          symbolPaint,
        );
        break;
      case PuzzleMarkerType.hint:
        // Question mark for hint
        final textPainter = TextPainter(
          text: TextSpan(
            text: '?',
            style: TextStyle(
              color: Colors.white,
              fontSize: size.width * 0.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            center.dx - textPainter.width / 2,
            center.dy - textPainter.height / 2,
          ),
        );
        break;
      case PuzzleMarkerType.none:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PuzzleMarkerPainter oldDelegate) {
    return oldDelegate.type != type;
  }
}
