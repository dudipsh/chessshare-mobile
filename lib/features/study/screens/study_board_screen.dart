import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';

import '../../../app/theme/colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/study_board.dart';
import '../providers/study_board_provider.dart';
import '../services/study_service.dart';

class StudyBoardScreen extends ConsumerStatefulWidget {
  final StudyBoard board;

  const StudyBoardScreen({super.key, required this.board});

  @override
  ConsumerState<StudyBoardScreen> createState() => _StudyBoardScreenState();
}

class _StudyBoardScreenState extends ConsumerState<StudyBoardScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBoardWithProgress();
    });
  }

  Future<void> _loadBoardWithProgress() async {
    final userId = ref.read(authProvider).profile?.id;

    // Fetch fresh board data with progress using RPC
    final freshBoard = await StudyService.getBoard(
      widget.board.id,
      userId: userId,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      ref.read(studyBoardProvider.notifier).loadBoard(freshBoard ?? widget.board);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyBoardProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth - 16;

    // Show loading while fetching board data
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.board.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.board.title,
          style: const TextStyle(fontSize: 17),
        ),
        actions: [
          // Variation selector button (if multiple variations)
          if ((state.board?.variations.length ?? 0) > 1)
            IconButton(
              icon: const Icon(Icons.list),
              onPressed: () => _showVariationSelector(context, state, isDark),
              tooltip: 'Select variation',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Current variation indicator (compact)
              if ((state.board?.variations.length ?? 0) > 1)
                _buildCurrentVariationIndicator(state, isDark),

              // Progress indicator
              _buildProgressBar(state),

              // Chess board with markers
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Stack(
                  children: [
                    _buildChessboard(state, boardSize),
                    // Marker overlay
                    if (state.markerType != MarkerType.none && state.markerSquare != null)
                      _buildMarkerOverlay(state, boardSize),
                  ],
                ),
              ),

              // Control buttons (below the board)
              _buildControlButtons(state, isDark),

              // Feedback message
              if (state.feedback != null)
                _buildFeedback(state, isDark),

              // Instructions / status
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _getInstructions(state),
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 16),

              // Bottom action buttons
              if (state.state == StudyState.completed)
                _buildCompletedActions(state),

              // Stats
              _buildStats(state, isDark),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentVariationIndicator(StudyBoardState state, bool isDark) {
    final variations = state.board?.variations ?? [];
    if (variations.isEmpty) return const SizedBox.shrink();

    final currentVariation = variations[state.currentVariationIndex];

    return GestureDetector(
      onTap: () => _showVariationSelector(context, state, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              currentVariation.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${state.currentVariationIndex + 1}/${variations.length}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons(StudyBoardState state, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Back button
          _buildNavButton(
            icon: Icons.skip_previous_rounded,
            tooltip: 'Back',
            onPressed: state.moveIndex > 0
                ? () => ref.read(studyBoardProvider.notifier).goBack()
                : null,
            isDark: isDark,
          ),
          // Hint button
          _buildActionButton(
            icon: Icons.lightbulb_rounded,
            tooltip: 'Hint',
            color: Colors.amber,
            onPressed: state.state == StudyState.playing
                ? () => ref.read(studyBoardProvider.notifier).showHint()
                : null,
            isDark: isDark,
          ),
          // Flip board
          _buildActionButton(
            icon: Icons.sync_rounded,
            tooltip: 'Flip',
            color: AppColors.primary,
            onPressed: () => ref.read(studyBoardProvider.notifier).flipBoard(),
            isDark: isDark,
          ),
          // Reset
          _buildActionButton(
            icon: Icons.replay_rounded,
            tooltip: 'Reset',
            color: Colors.orange,
            onPressed: () => ref.read(studyBoardProvider.notifier).resetVariation(),
            isDark: isDark,
          ),
          // Next button
          _buildNavButton(
            icon: Icons.skip_next_rounded,
            tooltip: 'Next',
            onPressed: state.moveIndex < state.totalMoves
                ? () => ref.read(studyBoardProvider.notifier).goForward()
                : null,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required bool isDark,
  }) {
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isEnabled
                  ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 28,
              color: isEnabled
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.white24 : Colors.grey.shade400),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback? onPressed,
    required bool isDark,
  }) {
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isEnabled
                  ? color.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isEnabled
                  ? Border.all(color: color.withValues(alpha: 0.3), width: 1)
                  : null,
            ),
            child: Icon(
              icon,
              size: 22,
              color: isEnabled
                  ? color
                  : (isDark ? Colors.white24 : Colors.grey.shade400),
            ),
          ),
        ),
      ),
    );
  }

  void _showVariationSelector(BuildContext context, StudyBoardState state, bool isDark) {
    final variations = state.board?.variations ?? [];
    if (variations.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Select Variation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const Divider(),
            // Variations list
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: variations.length,
                itemBuilder: (context, index) {
                  final variation = variations[index];
                  final isSelected = index == state.currentVariationIndex;

                  return ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: variation.isCompleted
                            ? AppColors.success
                            : (isSelected
                                ? AppColors.primary
                                : (isDark ? Colors.white12 : Colors.grey.shade200)),
                      ),
                      child: Center(
                        child: variation.isCompleted
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                      ),
                    ),
                    title: Text(
                      variation.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: variation.completionPercentage > 0
                        ? Text(
                            '${variation.completionPercentage.toInt()}% completed',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                            ),
                          )
                        : null,
                    trailing: isSelected
                        ? Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(studyBoardProvider.notifier).loadVariation(index);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(StudyBoardState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            '${state.moveIndex}/${state.totalMoves}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.progress,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  state.state == StudyState.completed
                      ? AppColors.success
                      : AppColors.primary,
                ),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChessboard(StudyBoardState state, double boardSize) {
    final notifier = ref.read(studyBoardProvider.notifier);
    final isPlayable = state.state == StudyState.playing ||
        state.state == StudyState.correct;

    if (isPlayable && state.isUserTurn) {
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

  Widget _buildMarkerOverlay(StudyBoardState state, double boardSize) {
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

  Widget _buildMarkerIcon(MarkerType type, double size) {
    if (type == MarkerType.none) {
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
          painter: _StudyMarkerPainter(type),
        ),
      ),
    );
  }

  Widget _buildFeedback(StudyBoardState state, bool isDark) {
    Color color;
    switch (state.state) {
      case StudyState.correct:
      case StudyState.completed:
        color = AppColors.success;
        break;
      case StudyState.incorrect:
        color = AppColors.error;
        break;
      default:
        color = isDark ? Colors.white70 : Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Text(
        state.feedback!,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCompletedActions(StudyBoardState state) {
    final hasNextVariation = state.board != null &&
        state.currentVariationIndex < state.board!.variations.length - 1;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                ref.read(studyBoardProvider.notifier).resetVariation();
              },
              child: const Text('Try Again'),
            ),
          ),
          if (hasNextVariation) ...[
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  ref.read(studyBoardProvider.notifier).nextVariation();
                },
                child: const Text('Next Line'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStats(StudyBoardState state, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStatChip(
            Icons.check_circle_outline,
            '${state.completedMoves}',
            AppColors.success,
            isDark,
          ),
          const SizedBox(width: 16),
          _buildStatChip(
            Icons.lightbulb_outline,
            '${state.hintsUsed}',
            Colors.amber,
            isDark,
          ),
          const SizedBox(width: 16),
          _buildStatChip(
            Icons.close,
            '${state.mistakesMade}',
            AppColors.error,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
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

  String _getInstructions(StudyBoardState state) {
    switch (state.state) {
      case StudyState.loading:
        return 'Loading...';
      case StudyState.ready:
        return 'Select a variation to start';
      case StudyState.playing:
        if (state.isUserTurn) {
          return 'Your turn - find the best move';
        } else {
          return 'Waiting...';
        }
      case StudyState.correct:
        return 'Keep going!';
      case StudyState.incorrect:
        return 'That\'s not quite right. Try again!';
      case StudyState.completed:
        return 'Excellent! Line completed.';
    }
  }
}

/// Custom painter for study mode markers (V/X style like web)
class _StudyMarkerPainter extends CustomPainter {
  final MarkerType type;

  _StudyMarkerPainter(this.type);

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
      case MarkerType.valid:
        bgColor = const Color(0xFF22C55E); // Green
        borderColor = const Color(0xFF16A34A);
        break;
      case MarkerType.invalid:
        bgColor = const Color(0xFFEF4444); // Red
        borderColor = const Color(0xFFDC2626);
        break;
      case MarkerType.hint:
        bgColor = const Color(0xFFFACC15); // Yellow
        borderColor = const Color(0xFFEAB308);
        break;
      case MarkerType.none:
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
      case MarkerType.valid:
        // Checkmark
        final path = Path();
        path.moveTo(center.dx - size.width * 0.22, center.dy);
        path.lineTo(center.dx - size.width * 0.05, center.dy + size.height * 0.15);
        path.lineTo(center.dx + size.width * 0.22, center.dy - size.height * 0.15);
        canvas.drawPath(path, symbolPaint);
        break;
      case MarkerType.invalid:
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
      case MarkerType.hint:
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
      case MarkerType.none:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _StudyMarkerPainter oldDelegate) {
    return oldDelegate.type != type;
  }
}
