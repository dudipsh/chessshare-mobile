import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../models/analyzed_move.dart';
import '../models/chess_game.dart';
import '../models/move_classification.dart';
import '../widgets/move_markers.dart';

/// Screen for practicing mistakes from game analysis
class PracticeMistakesScreen extends ConsumerStatefulWidget {
  final List<AnalyzedMove> mistakes;
  final ChessGame game;
  final String reviewId;

  const PracticeMistakesScreen({
    super.key,
    required this.mistakes,
    required this.game,
    required this.reviewId,
  });

  @override
  ConsumerState<PracticeMistakesScreen> createState() =>
      _PracticeMistakesScreenState();
}

class _PracticeMistakesScreenState
    extends ConsumerState<PracticeMistakesScreen> {
  int _currentIndex = 0;
  Chess? _position;
  Chess? _originalPosition; // For resetting after wrong move
  Side _orientation = Side.white;
  PracticeState _state = PracticeState.ready;
  String? _feedback;
  int _correctCount = 0;
  int _wrongAttempts = 0;
  static const int _maxWrongAttempts = 3;
  NormalMove? _lastMove;
  NormalMove? _pendingMove; // The move being attempted
  bool _showHint = false;
  MoveClassification? _feedbackMarker;

  AnalyzedMove get currentMistake => widget.mistakes[_currentIndex];

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  void _loadPosition() {
    final mistake = currentMistake;
    _originalPosition = Chess.fromSetup(Setup.parseFen(mistake.fen));
    _position = Chess.fromSetup(Setup.parseFen(mistake.fen));
    _orientation = mistake.color == 'white' ? Side.white : Side.black;
    _state = PracticeState.ready;
    _feedback = null;
    _feedbackMarker = null;
    _wrongAttempts = 0;
    _lastMove = null;
    _pendingMove = null;
    _showHint = false;
    setState(() {});
  }

  void _makeMove(NormalMove move) {
    if (_position == null || _state != PracticeState.ready) return;

    final uciMove =
        '${move.from.name}${move.to.name}${move.promotion?.letter ?? ''}';
    final bestMoveUci = currentMistake.bestMoveUci;

    _pendingMove = move;

    // Check if the move is correct (matches best move)
    if (uciMove == bestMoveUci) {
      // Correct move!
      _correctCount++;
      _state = PracticeState.correct;
      _feedback = 'Correct! That was the best move.';
      _feedbackMarker = MoveClassification.best;
      _lastMove = move;
      _position = _position!.play(move) as Chess;
      setState(() {});
    } else {
      // Wrong move - show marker and reset board
      _wrongAttempts++;
      _state = PracticeState.wrong;
      _feedbackMarker = MoveClassification.blunder;
      _lastMove = move;
      // Temporarily play the move to show where they put the piece
      _position = _position!.play(move) as Chess;
      setState(() {});

      if (_wrongAttempts >= _maxWrongAttempts) {
        _feedback = 'The best move was ${currentMistake.bestMove}';
        // Show the correct move after a delay
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            _showCorrectMove();
          }
        });
      } else {
        _feedback = 'Try again (${_maxWrongAttempts - _wrongAttempts} attempts left)';
        // Reset board after showing wrong move feedback
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && _state == PracticeState.wrong) {
            setState(() {
              // Reset position to original
              _position = Chess.fromSetup(Setup.parseFen(currentMistake.fen));
              _lastMove = null;
              _state = PracticeState.ready;
              _feedback = null;
              _feedbackMarker = null;
            });
          }
        });
      }
    }
  }

  void _showCorrectMove() {
    final bestMoveUci = currentMistake.bestMoveUci;
    if (bestMoveUci != null && bestMoveUci.length >= 4) {
      try {
        // First reset to original position
        _position = Chess.fromSetup(Setup.parseFen(currentMistake.fen));

        final from = Square.fromName(bestMoveUci.substring(0, 2));
        final to = Square.fromName(bestMoveUci.substring(2, 4));
        Role? promotion;
        if (bestMoveUci.length > 4) {
          switch (bestMoveUci[4].toLowerCase()) {
            case 'q':
              promotion = Role.queen;
              break;
            case 'r':
              promotion = Role.rook;
              break;
            case 'b':
              promotion = Role.bishop;
              break;
            case 'n':
              promotion = Role.knight;
              break;
          }
        }
        final move = NormalMove(from: from, to: to, promotion: promotion);
        _lastMove = move;
        _position = _position!.play(move) as Chess;
        _state = PracticeState.showingSolution;
        _feedbackMarker = MoveClassification.best;
        setState(() {});
      } catch (e) {
        debugPrint('Error showing correct move: $e');
      }
    }
  }

  void _nextPuzzle() {
    if (_currentIndex < widget.mistakes.length - 1) {
      _currentIndex++;
      _loadPosition();
    } else {
      // All puzzles completed
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Practice Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '$_correctCount / ${widget.mistakes.length} correct',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Accuracy: ${(_correctCount / widget.mistakes.length * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Restart
              setState(() {
                _currentIndex = 0;
                _correctCount = 0;
                _loadPosition();
              });
            },
            child: const Text('Try Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _toggleHint() {
    setState(() {
      _showHint = !_showHint;
    });
  }

  IMap<Square, ISet<Square>> _getValidMoves() {
    if (_position == null || _state != PracticeState.ready) {
      return IMap(const {});
    }

    return _convertToValidMoves(_position!.legalMoves);
  }

  /// Convert dartchess SquareSet to chessground ISet<Square>
  IMap<Square, ISet<Square>> _convertToValidMoves(
      IMap<Square, SquareSet> dartchessMoves) {
    final Map<Square, ISet<Square>> result = {};
    for (final entry in dartchessMoves.entries) {
      final squares = <Square>[];
      for (final sq in entry.value.squares) {
        squares.add(sq);
      }
      result[entry.key] = ISet(squares);
    }
    return IMap(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth - 16;

    return Scaffold(
      appBar: AppBar(
        title: Text('Practice (${_currentIndex + 1}/${widget.mistakes.length})'),
        actions: [
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Mistake info
            _buildMistakeInfo(isDark),

            // Chess board with marker overlay
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Stack(
                children: [
                  _buildChessboard(boardSize),
                  // Feedback marker overlay
                  if (_feedbackMarker != null && _lastMove != null)
                    _buildFeedbackMarker(boardSize),
                  // Hint arrow
                  if (_showHint && currentMistake.bestMoveUci != null)
                    _buildHintArrow(boardSize),
                ],
              ),
            ),

            // Attempt indicators (dots)
            _buildAttemptIndicators(),

            // Hint button (below board)
            if (_state == PracticeState.ready)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: OutlinedButton.icon(
                  onPressed: _toggleHint,
                  icon: Icon(
                    _showHint ? Icons.lightbulb : Icons.lightbulb_outline,
                    color: _showHint ? Colors.amber : null,
                  ),
                  label: Text(_showHint ? 'Hide Hint' : 'Show Hint'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ),

            // Feedback message
            if (_feedback != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: _state == PracticeState.correct
                      ? AppColors.success.withValues(alpha: 0.15)
                      : _state == PracticeState.wrong
                          ? AppColors.error.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _state == PracticeState.correct
                          ? Icons.check_circle
                          : _state == PracticeState.wrong ||
                                  _state == PracticeState.showingSolution
                              ? Icons.error
                              : Icons.info,
                      color: _state == PracticeState.correct
                          ? AppColors.success
                          : _state == PracticeState.wrong ||
                                  _state == PracticeState.showingSolution
                              ? AppColors.error
                              : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _feedback!,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _state == PracticeState.correct
                              ? AppColors.success
                              : _state == PracticeState.wrong ||
                                      _state == PracticeState.showingSolution
                                  ? AppColors.error
                                  : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Instructions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _getInstructions(),
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Progress bar
            _buildProgressBar(),

            // Action buttons
            if (_state == PracticeState.correct ||
                _state == PracticeState.showingSolution)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _loadPosition,
                        child: const Text('Retry'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _nextPuzzle,
                        child: Text(
                            _currentIndex < widget.mistakes.length - 1
                                ? 'Next'
                                : 'Finish'),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAttemptIndicators() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Attempts: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),
          ...List.generate(_maxWrongAttempts, (i) {
            return Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _wrongAttempts
                    ? AppColors.error
                    : Colors.grey.withValues(alpha: 0.3),
                border: Border.all(
                  color: i < _wrongAttempts
                      ? AppColors.error
                      : Colors.grey.withValues(alpha: 0.5),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMistakeInfo(bool isDark) {
    final mistake = currentMistake;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: mistake.classification.color.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
              color: mistake.classification.color.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          // Classification badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: mistake.classification.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(mistake.classification.icon,
                    size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  mistake.classification.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Move played
          Text(
            'You played: ${mistake.san}',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey[700],
              fontSize: 14,
            ),
          ),
          const Spacer(),
          // Side to move
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: mistake.color == 'white' ? Colors.white : Colors.grey.shade800,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChessboard(double boardSize) {
    if (_position == null) {
      return SizedBox(width: boardSize, height: boardSize);
    }

    final isPlayable = _state == PracticeState.ready;

    if (isPlayable) {
      return Chessboard(
        size: boardSize,
        settings: _buildBoardSettings(),
        orientation: _orientation,
        fen: _position!.fen,
        lastMove: _lastMove,
        game: GameData(
          playerSide:
              _orientation == Side.white ? PlayerSide.white : PlayerSide.black,
          sideToMove: _position!.turn,
          validMoves: _getValidMoves(),
          promotionMove: null,
          onMove: (move, {isDrop}) {
            _makeMove(move);
          },
          onPromotionSelection: (role) {},
        ),
      );
    } else {
      return Chessboard.fixed(
        size: boardSize,
        settings: _buildBoardSettings(),
        orientation: _orientation,
        fen: _position!.fen,
        lastMove: _lastMove,
      );
    }
  }

  Widget _buildFeedbackMarker(double boardSize) {
    if (_lastMove == null || _feedbackMarker == null) {
      return const SizedBox.shrink();
    }

    final squareSize = boardSize / 8;
    final markerSize = squareSize * 0.45;
    final toSquare = _lastMove!.to;

    // Calculate position based on orientation
    double x;
    double y;

    if (_orientation == Side.black) {
      x = (7 - toSquare.file).toDouble();
      y = toSquare.rank.toDouble();
    } else {
      x = toSquare.file.toDouble();
      y = (7 - toSquare.rank).toDouble();
    }

    // Position marker in top-right corner of the square
    final left = x * squareSize + squareSize - markerSize * 1.1;
    final top = y * squareSize + markerSize * 0.1;

    return Positioned(
      left: left,
      top: top,
      child: MoveMarker(
        classification: _feedbackMarker!,
        size: markerSize,
      ),
    );
  }

  Widget _buildHintArrow(double boardSize) {
    final bestMoveUci = currentMistake.bestMoveUci;
    if (bestMoveUci == null || bestMoveUci.length < 4) {
      return const SizedBox.shrink();
    }

    final squareSize = boardSize / 8;
    try {
      final from = Square.fromName(bestMoveUci.substring(0, 2));
      final to = Square.fromName(bestMoveUci.substring(2, 4));

      // Calculate positions based on orientation
      double fromX, fromY, toX, toY;
      if (_orientation == Side.black) {
        fromX = (7 - from.file + 0.5) * squareSize;
        fromY = (from.rank + 0.5) * squareSize;
        toX = (7 - to.file + 0.5) * squareSize;
        toY = (to.rank + 0.5) * squareSize;
      } else {
        fromX = (from.file + 0.5) * squareSize;
        fromY = (7 - from.rank + 0.5) * squareSize;
        toX = (to.file + 0.5) * squareSize;
        toY = (7 - to.rank + 0.5) * squareSize;
      }

      return CustomPaint(
        size: Size(boardSize, boardSize),
        painter: _ArrowPainter(
          from: Offset(fromX, fromY),
          to: Offset(toX, toY),
          color: MoveClassification.best.color.withValues(alpha: 0.7),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_correctCount correct',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${widget.mistakes.length - _currentIndex - 1} remaining',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentIndex + 1) / widget.mistakes.length,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.grid_on),
              title: const Text('Board Theme'),
              subtitle: const Text('Green (Default)'),
              onTap: () {
                // TODO: Implement board theme selection
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.extension),
              title: const Text('Piece Style'),
              subtitle: const Text('Merida (Default)'),
              onTap: () {
                // TODO: Implement piece style selection
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.volume_up),
              title: const Text('Sound Effects'),
              trailing: Switch(
                value: true, // TODO: Connect to actual setting
                onChanged: (value) {
                  // TODO: Implement sound toggle
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
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

  String _getInstructions() {
    switch (_state) {
      case PracticeState.ready:
        return 'Find the best move';
      case PracticeState.correct:
        return 'Well done!';
      case PracticeState.wrong:
        return 'Not quite right...';
      case PracticeState.showingSolution:
        return 'This was the best move';
    }
  }
}

enum PracticeState {
  ready,
  correct,
  wrong,
  showingSolution,
}

/// Custom painter for drawing arrows on the board
class _ArrowPainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final Color color;

  _ArrowPainter({
    required this.from,
    required this.to,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw the line
    canvas.drawLine(from, to, paint);

    // Draw arrowhead
    final direction = (to - from);
    final angle = direction.direction;
    const arrowSize = 20.0;
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(to.dx, to.dy);
    path.lineTo(
      to.dx - arrowSize * 1.2 * (to.dx - from.dx).sign,
      to.dy - arrowSize * 0.6,
    );
    path.lineTo(
      to.dx - arrowSize * 1.2 * (to.dx - from.dx).sign,
      to.dy + arrowSize * 0.6,
    );
    path.close();
    canvas.drawPath(path, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
