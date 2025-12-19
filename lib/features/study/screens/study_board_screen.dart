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
          // Hint button
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: () {
              ref.read(studyBoardProvider.notifier).showHint();
            },
            tooltip: 'Hint',
          ),
          // Flip board
          IconButton(
            icon: const Icon(Icons.swap_vert),
            onPressed: () {
              ref.read(studyBoardProvider.notifier).flipBoard();
            },
            tooltip: 'Flip board',
          ),
          // Reset
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(studyBoardProvider.notifier).resetVariation();
            },
            tooltip: 'Reset',
          ),
        ],
      ),
      body: Column(
        children: [
          // Variation selector (show if board has multiple variations)
          if ((state.board?.variations.length ?? 0) > 1)
            _buildVariationSelector(state, isDark),

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

          const Spacer(),

          // Bottom action buttons
          if (state.state == StudyState.completed)
            _buildCompletedActions(state),

          // Stats
          _buildStats(state, isDark),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildVariationSelector(StudyBoardState state, bool isDark) {
    final variations = state.board?.variations ?? [];

    if (variations.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: variations.length,
        itemBuilder: (context, index) {
          final variation = variations[index];
          final isSelected = index == state.currentVariationIndex;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    variation.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                  // Show progress indicator if started
                  if (variation.completionPercentage > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: variation.isCompleted
                            ? AppColors.success
                            : (isSelected ? Colors.white24 : AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: variation.isCompleted
                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                            : Text(
                                '${variation.completionPercentage.toInt()}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : AppColors.primary,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              onSelected: (_) {
                ref.read(studyBoardProvider.notifier).loadVariation(index);
              },
            ),
          );
        },
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
    IconData icon;
    Color color;

    switch (type) {
      case MarkerType.valid:
        icon = Icons.check_circle;
        color = AppColors.success;
        break;
      case MarkerType.invalid:
        icon = Icons.cancel;
        color = AppColors.error;
        break;
      case MarkerType.hint:
        icon = Icons.help;
        color = Colors.blue;
        break;
      case MarkerType.none:
        return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        width: size * 0.5,
        height: size * 0.5,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: size * 0.4,
          color: color,
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
