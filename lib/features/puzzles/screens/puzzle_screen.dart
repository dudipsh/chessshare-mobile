import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../core/providers/board_settings_provider.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/widgets/board_settings_sheet.dart';
import '../models/puzzle.dart';
import '../providers/puzzle_provider.dart';
import 'puzzle/puzzle_action_buttons.dart';
import 'puzzle/puzzle_feedback.dart';
import 'puzzle/puzzle_info_bar.dart';
import 'puzzle/puzzle_marker_painter.dart';

class PuzzleScreen extends ConsumerStatefulWidget {
  final Puzzle puzzle;
  final List<Puzzle>? puzzlesList;
  final int? currentIndex;

  const PuzzleScreen({
    super.key,
    required this.puzzle,
    this.puzzlesList,
    this.currentIndex,
  });

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  bool _loadAttempted = false;
  late Puzzle _currentPuzzle;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentPuzzle = widget.puzzle;
    _currentIndex = widget.currentIndex ?? 0;

    // Load puzzle once on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_loadAttempted) {
        _loadAttempted = true;
        ref.read(puzzleSolveProvider.notifier).loadPuzzle(_currentPuzzle);
      }
    });
  }

  bool get _hasNextPuzzle {
    final puzzlesList = widget.puzzlesList;
    if (puzzlesList == null) return false;
    return _currentIndex < puzzlesList.length - 1;
  }

  void _goToNextPuzzle() {
    final puzzlesList = widget.puzzlesList;
    if (puzzlesList == null || !_hasNextPuzzle) return;

    setState(() {
      _currentIndex++;
      _currentPuzzle = puzzlesList[_currentIndex];
    });

    ref.read(puzzleSolveProvider.notifier).loadPuzzle(_currentPuzzle);
  }

  void _showSettings() {
    showBoardSettingsSheet(
      context: context,
      ref: ref,
      onFlipBoard: () {
        ref.read(puzzleSolveProvider.notifier).flipBoard();
      },
    );
  }

  /// Play move sound and haptic feedback
  /// Uses SoLoud for instant, non-blocking audio
  void _playMoveSound(NormalMove move, String fen) {
    try {
      final position = Chess.fromSetup(Setup.parseFen(fen));
      final san = position.makeSan(move).$2;
      final isCapture = san.contains('x');
      final isCheck = san.contains('+') || san.contains('#');
      final isCastle = san == 'O-O' || san == 'O-O-O';

      Chess? positionAfter;
      try {
        positionAfter = position.play(move) as Chess;
      } catch (_) {}

      // Single call handles both sound and vibration
      ref.read(audioServiceProvider).playMoveWithHaptic(
        isCapture: isCapture,
        isCheck: isCheck,
        isCastle: isCastle,
        isCheckmate: positionAfter?.isCheckmate ?? false,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final puzzleState = ref.watch(puzzleSolveProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth - 16;

    // Build title with progress if we have a list
    String title = _currentPuzzle.theme.displayName;
    if (widget.puzzlesList != null) {
      title = '${_currentIndex + 1}/${widget.puzzlesList!.length} - $title';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
            tooltip: 'Board settings',
          ),
        ],
      ),
      body: Column(
        children: [
          PuzzleInfoBar(sideToMove: _currentPuzzle.sideToMove, rating: _currentPuzzle.rating),
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
              onNextPuzzle: _hasNextPuzzle ? _goToNextPuzzle : null,
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildChessboard(WidgetRef ref, PuzzleSolveState state, double boardSize) {
    final notifier = ref.read(puzzleSolveProvider.notifier);
    final boardSettings = ref.watch(boardSettingsProvider);
    final isPlayable = state.state == PuzzleState.playing;

    final settings = ChessboardSettings(
      pieceAssets: boardSettings.pieceSet.pieceSet.assets,
      colorScheme: ChessboardColorScheme(
        lightSquare: boardSettings.colorScheme.lightSquare,
        darkSquare: boardSettings.colorScheme.darkSquare,
        background: SolidColorChessboardBackground(
          lightSquare: boardSettings.colorScheme.lightSquare,
          darkSquare: boardSettings.colorScheme.darkSquare,
        ),
        whiteCoordBackground: SolidColorChessboardBackground(
          lightSquare: boardSettings.colorScheme.lightSquare,
          darkSquare: boardSettings.colorScheme.darkSquare,
          coordinates: true,
        ),
        blackCoordBackground: SolidColorChessboardBackground(
          lightSquare: boardSettings.colorScheme.lightSquare,
          darkSquare: boardSettings.colorScheme.darkSquare,
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

    if (isPlayable) {
      return RepaintBoundary(
        child: Chessboard(
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
            onMove: (move, {isDrop}) {
              // Make the move first (UI update is priority)
              notifier.makeMove(move);
              // Then play sound and haptic (instant with SoLoud)
              _playMoveSound(move, state.currentFen);
            },
            onPromotionSelection: (role) {},
          ),
        ),
      );
    } else {
      return RepaintBoundary(
        child: Chessboard.fixed(
          size: boardSize,
          settings: settings,
          orientation: state.orientation,
          fen: state.currentFen,
          lastMove: state.lastMove,
        ),
      );
    }
  }
}
