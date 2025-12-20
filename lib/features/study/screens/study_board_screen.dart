import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';

import '../../../app/theme/colors.dart';
import '../../../core/providers/board_settings_provider.dart';
import '../../../core/widgets/board_settings_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/study_board.dart';
import '../providers/study_board_provider.dart';
import '../services/study_service.dart';
import 'study_board/control_buttons.dart';
import 'study_board/study_marker_painter.dart';
import 'study_board/study_progress_bar.dart';
import 'study_board/study_stats.dart';
import 'study_board/variation_selector_sheet.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBoardWithProgress());
  }

  Future<void> _loadBoardWithProgress() async {
    final userId = ref.read(authProvider).profile?.id;
    final freshBoard = await StudyService.getBoard(widget.board.id, userId: userId);

    if (mounted) {
      setState(() => _isLoading = false);
      ref.read(studyBoardProvider.notifier).loadBoard(freshBoard ?? widget.board);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyBoardProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth - 16;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.board.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(state, isDark),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              if ((state.board?.variations.length ?? 0) > 1)
                _buildCurrentVariationIndicator(state, isDark),
              StudyProgressBar(
                moveIndex: state.moveIndex,
                totalMoves: state.totalMoves,
                progress: state.progress,
                isCompleted: state.state == StudyState.completed,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Stack(
                  children: [
                    _buildChessboard(state, boardSize),
                    if (state.markerType != MarkerType.none && state.markerSquare != null)
                      _buildMarkerOverlay(state, boardSize),
                  ],
                ),
              ),
              ControlButtons(
                moveIndex: state.moveIndex,
                totalMoves: state.totalMoves,
                isPlaying: state.state == StudyState.playing,
                onBack: () => ref.read(studyBoardProvider.notifier).goBack(),
                onForward: () => ref.read(studyBoardProvider.notifier).goForward(),
                onHint: () => ref.read(studyBoardProvider.notifier).showHint(),
                onFlip: () => ref.read(studyBoardProvider.notifier).flipBoard(),
                onReset: () => ref.read(studyBoardProvider.notifier).resetVariation(),
                isDark: isDark,
              ),
              if (state.feedback != null) _buildFeedback(state, isDark),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _getInstructions(state),
                  style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              if (state.state == StudyState.completed) _buildCompletedActions(state),
              StudyStats(
                completedMoves: state.completedMoves,
                hintsUsed: state.hintsUsed,
                mistakesMade: state.mistakesMade,
                isDark: isDark,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(StudyBoardState state, bool isDark) {
    return AppBar(
      title: Text(widget.board.title, style: const TextStyle(fontSize: 17)),
      actions: [
        if ((state.board?.variations.length ?? 0) > 1)
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => _showVariationSelector(state, isDark),
            tooltip: 'Select variation',
          ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => showBoardSettingsSheet(
            context: context,
            ref: ref,
            onFlipBoard: () => ref.read(studyBoardProvider.notifier).flipBoard(),
          ),
          tooltip: 'Board settings',
        ),
      ],
    );
  }

  void _showVariationSelector(StudyBoardState state, bool isDark) {
    showVariationSelectorSheet(
      context: context,
      variations: state.board?.variations ?? [],
      currentIndex: state.currentVariationIndex,
      isDark: isDark,
      onSelect: (index) => ref.read(studyBoardProvider.notifier).loadVariation(index),
    );
  }

  Widget _buildCurrentVariationIndicator(StudyBoardState state, bool isDark) {
    final variations = state.board?.variations ?? [];
    if (variations.isEmpty) return const SizedBox.shrink();

    final currentVariation = variations[state.currentVariationIndex];

    return GestureDetector(
      onTap: () => _showVariationSelector(state, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                currentVariation.name,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${state.currentVariationIndex + 1}/${variations.length}',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 20, color: isDark ? Colors.white54 : Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildChessboard(StudyBoardState state, double boardSize) {
    final notifier = ref.read(studyBoardProvider.notifier);
    final isPlayable = state.state == StudyState.playing || state.state == StudyState.correct;

    if (isPlayable && state.isUserTurn) {
      return Chessboard(
        size: boardSize,
        settings: _buildBoardSettings(),
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
    int file = square.file;
    int rank = square.rank;

    double left = state.orientation == Side.black ? (7 - file) * squareSize : file * squareSize;
    double top = state.orientation == Side.black ? rank * squareSize : (7 - rank) * squareSize;

    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: squareSize,
        height: squareSize,
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.all(squareSize * 0.04),
            child: CustomPaint(
              size: Size(squareSize * 0.4, squareSize * 0.4),
              painter: StudyMarkerPainter(state.markerType),
            ),
          ),
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
      child: Text(state.feedback!, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
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
              onPressed: () => ref.read(studyBoardProvider.notifier).resetVariation(),
              child: const Text('Try Again'),
            ),
          ),
          if (hasNextVariation) ...[
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => ref.read(studyBoardProvider.notifier).nextVariation(),
                child: const Text('Next Line'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  ChessboardSettings _buildBoardSettings() {
    final boardSettings = ref.watch(boardSettingsProvider);
    final lightSquare = boardSettings.colorScheme.lightSquare;
    final darkSquare = boardSettings.colorScheme.darkSquare;
    final pieceAssets = boardSettings.pieceSet.pieceSet.assets;

    return ChessboardSettings(
      pieceAssets: pieceAssets,
      colorScheme: ChessboardColorScheme(
        lightSquare: lightSquare,
        darkSquare: darkSquare,
        background: SolidColorChessboardBackground(lightSquare: lightSquare, darkSquare: darkSquare),
        whiteCoordBackground: SolidColorChessboardBackground(lightSquare: lightSquare, darkSquare: darkSquare, coordinates: true),
        blackCoordBackground: SolidColorChessboardBackground(lightSquare: lightSquare, darkSquare: darkSquare, coordinates: true, orientation: Side.black),
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
        return state.isUserTurn ? 'Your turn - find the best move' : 'Waiting...';
      case StudyState.correct:
        return 'Keep going!';
      case StudyState.incorrect:
        return 'That\'s not quite right. Try again!';
      case StudyState.completed:
        return 'Excellent! Line completed.';
    }
  }
}
