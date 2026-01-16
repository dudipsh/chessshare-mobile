import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';

import '../../../app/theme/colors.dart';
import '../../../core/providers/board_settings_provider.dart';
import '../../../core/providers/captured_pieces_provider.dart';
import '../../../core/widgets/board_settings_factory.dart';
import '../../../core/widgets/board_settings_sheet.dart';
import '../../../core/widgets/chess_board_shell.dart';
import '../../analysis/providers/engine_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/study_board.dart';
import '../providers/study_board_provider.dart';
import '../providers/study_history_provider.dart';
import '../services/study_service.dart';
import 'study_board/control_buttons.dart';
import 'study_board/study_marker_painter.dart';
import 'study_board/study_progress_bar.dart';
import 'study_board/variation_selector_sheet.dart';

class StudyBoardScreen extends ConsumerStatefulWidget {
  final StudyBoard board;

  const StudyBoardScreen({super.key, required this.board});

  @override
  ConsumerState<StudyBoardScreen> createState() => _StudyBoardScreenState();
}

class _StudyBoardScreenState extends ConsumerState<StudyBoardScreen> {
  bool _isLoading = true;
  String? _lastAnalyzedFen;
  bool _wasEngineReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBoardWithProgress();
      _initializeEngine();
    });
  }

  Future<void> _initializeEngine() async {
    // Initialize engine for position evaluation
    final engineNotifier = ref.read(engineAnalysisProvider.notifier);
    await engineNotifier.initialize();
  }

  Future<void> _loadBoardWithProgress() async {
    final userId = ref.read(authProvider).profile?.id;
    final freshBoard = await StudyService.getBoard(widget.board.id, userId: userId);

    if (mounted) {
      setState(() => _isLoading = false);
      final boardToUse = freshBoard ?? widget.board;
      ref.read(studyBoardProvider.notifier).loadBoard(boardToUse);

      // Record view for history
      ref.read(studyHistoryProvider.notifier).recordView(boardToUse);
    }
  }

  void _analyzeCurrentPosition(String fen, bool isEngineReady) {
    if (!isEngineReady) return;

    // Analyze if position changed OR if engine just became ready
    final engineJustBecameReady = isEngineReady && !_wasEngineReady;
    final positionChanged = fen != _lastAnalyzedFen;

    if (positionChanged || engineJustBecameReady) {
      _lastAnalyzedFen = fen;
      ref.read(engineAnalysisProvider.notifier).analyzePosition(fen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyBoardProvider);
    final engineState = ref.watch(engineAnalysisProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth - 16;

    // Analyze position when it changes or engine becomes ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.currentFen.isNotEmpty) {
        _analyzeCurrentPosition(state.currentFen, engineState.isReady);
        _wasEngineReady = engineState.isReady;
      }
    });

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.board.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(state, isDark, engineState),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              if ((state.board?.variations.length ?? 0) > 1)
                _buildCurrentVariationIndicator(state, isDark),
              StudyProgressBar(
                moveIndex: state.currentFullMoves,
                totalMoves: state.totalFullMoves,
                progress: state.progress,
                isCompleted: state.state == StudyState.completed,
                isDark: isDark,
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
              // Container for feedback + instructions with minimum height
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 80),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.feedback != null) _buildFeedback(state, isDark),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        _getInstructions(state),
                        style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.grey.shade700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              if (state.state == StudyState.completed) _buildCompletedActions(state),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(StudyBoardState state, bool isDark, EngineAnalysisState engineState) {
    return AppBar(
      title: Row(
        children: [
          _buildEvaluationBadge(engineState, isDark),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.board.title,
              style: const TextStyle(fontSize: 17),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
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

  Widget _buildEvaluationBadge(EngineAnalysisState engineState, bool isDark) {
    final evaluation = engineState.evaluation;

    // Default values for when no evaluation is available
    String text = '0.0';
    Color bgColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;
    Color textColor = isDark ? Colors.white : Colors.black87;

    if (evaluation != null) {
      // Format: show sign only when needed, max 1 decimal
      final cp = evaluation.centipawns;
      final mate = evaluation.mateInMoves;

      if (mate != null) {
        // Mate score
        text = mate > 0 ? 'M$mate' : 'M$mate';
        bgColor = mate > 0 ? Colors.white : Colors.grey.shade800;
        textColor = mate > 0 ? Colors.black87 : Colors.white;
      } else if (cp != null) {
        // Centipawn score - convert to pawns with 1 decimal
        final pawns = cp / 100;
        if (pawns > 0) {
          text = '+${pawns.toStringAsFixed(1)}';
          bgColor = Colors.white;
          textColor = Colors.black87;
        } else if (pawns < 0) {
          text = pawns.toStringAsFixed(1); // Already has minus sign
          bgColor = Colors.grey.shade800;
          textColor = Colors.white;
        } else {
          text = '0.0';
        }
      }
    }

    // Fixed width container to keep consistent layout
    return Container(
      width: 52, // Fixed width for consistent positioning
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          width: 1,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
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
    final hasMultipleVariations = variations.length > 1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasMultipleVariations ? () => _showVariationSelector(state, isDark) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: hasMultipleVariations
                ? Border.all(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Line name - center (clickable)
              Flexible(
                child: Text(
                  currentVariation.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                    decoration: hasMultipleVariations ? TextDecoration.underline : null,
                    decorationColor: isDark ? Colors.white38 : Colors.black38,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (hasMultipleVariations) ...[
                const SizedBox(width: 8),
                Text(
                  '${state.currentVariationIndex + 1}/${variations.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChessboard(StudyBoardState state, double boardSize) {
    final notifier = ref.read(studyBoardProvider.notifier);
    final isPlayable = state.state == StudyState.playing || state.state == StudyState.correct;
    final boardSettings = ref.watch(boardSettingsProvider);
    final settings = BoardSettingsFactory.create(boardSettings: boardSettings);

    // Update captured pieces
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(capturedPiecesProvider.notifier).updateFromFen(state.currentFen);
    });

    Widget chessBoard;
    if (isPlayable && state.isUserTurn) {
      chessBoard = Chessboard(
        size: boardSize,
        settings: settings,
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
      chessBoard = Chessboard.fixed(
        size: boardSize,
        settings: settings,
        orientation: state.orientation,
        fen: state.currentFen,
        lastMove: state.lastMove,
      );
    }

    // Return board wrapped in shell with captured pieces
    return ChessBoardShell(
      board: chessBoard,
      orientation: state.orientation,
      fen: state.currentFen,
      showCapturedPieces: true,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildMarkerOverlay(StudyBoardState state, double boardSize) {
    final squareSize = boardSize / 8;
    final square = state.markerSquare!;
    int file = square.file;
    int rank = square.rank;

    // Account for the captured pieces slot at the top (24px default height in ChessBoardShell)
    const capturedPiecesSlotHeight = 24.0;

    double left = state.orientation == Side.black ? (7 - file) * squareSize : file * squareSize;
    double top = state.orientation == Side.black ? rank * squareSize : (7 - rank) * squareSize;
    top += capturedPiecesSlotHeight; // Offset for captured pieces slot

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
