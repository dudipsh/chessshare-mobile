import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../core/providers/board_settings_provider.dart';
import '../../../core/services/audio_service.dart';
import '../models/puzzle.dart';
import '../providers/daily_puzzle_provider.dart';
import '../providers/puzzle_provider.dart';
import '../widgets/daily_puzzle_empty_view.dart';
import '../widgets/daily_puzzle_helpers.dart';
import '../widgets/daily_puzzle_solved_view.dart';
import '../widgets/date_navigation_header.dart';
import 'puzzle/puzzle_marker_painter.dart';

class DailyPuzzleScreen extends ConsumerStatefulWidget {
  const DailyPuzzleScreen({super.key});

  @override
  ConsumerState<DailyPuzzleScreen> createState() => _DailyPuzzleScreenState();
}

class _DailyPuzzleScreenState extends ConsumerState<DailyPuzzleScreen> {
  bool _puzzleLoaded = false;
  String? _loadedDateKey;

  @override
  Widget build(BuildContext context) {
    final dailyState = ref.watch(dailyPuzzleProvider);
    final puzzleState = ref.watch(puzzleSolveProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Load puzzle when available - reset if date changed
    final currentDateKey = dailyState.dateKey;
    if (dailyState.puzzle != null && !dailyState.isSolved) {
      if (!_puzzleLoaded || _loadedDateKey != currentDateKey) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_puzzleLoaded || _loadedDateKey != currentDateKey) {
            _puzzleLoaded = true;
            _loadedDateKey = currentDateKey;
            ref.read(puzzleSolveProvider.notifier).loadPuzzle(dailyState.puzzle!);
          }
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Puzzle'),
        actions: [
          if (!dailyState.isToday)
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: () => _goToToday(),
              tooltip: 'Go to Today',
            ),
          if (dailyState.streak > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    '${dailyState.streak}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
          if (!dailyState.isSolved && dailyState.puzzle != null)
            IconButton(
              icon: const Icon(Icons.lightbulb_outline),
              onPressed: () => ref.read(puzzleSolveProvider.notifier).showHint(),
              tooltip: 'Hint',
            ),
        ],
      ),
      body: _buildBody(context, dailyState, puzzleState, isDark),
    );
  }

  void _goToToday() {
    _puzzleLoaded = false;
    ref.read(dailyPuzzleProvider.notifier).goToToday();
  }

  void _previousDay() {
    _puzzleLoaded = false;
    ref.read(dailyPuzzleProvider.notifier).previousDay();
  }

  void _nextDay() {
    _puzzleLoaded = false;
    ref.read(dailyPuzzleProvider.notifier).nextDay();
  }

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

      ref.read(audioServiceProvider).playMoveSound(
        isCapture: isCapture,
        isCheck: isCheck,
        isCastle: isCastle,
        isCheckmate: positionAfter?.isCheckmate ?? false,
      );
    } catch (_) {}
  }

  Widget _buildBody(
    BuildContext context,
    DailyPuzzleState dailyState,
    PuzzleSolveState puzzleState,
    bool isDark,
  ) {
    if (dailyState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (dailyState.isSolved) {
      return DailyPuzzleSolvedView(
        state: dailyState,
        isDark: isDark,
        onPrevious: _previousDay,
        onNext: _nextDay,
        onGoToToday: _goToToday,
      );
    }

    if (dailyState.puzzle == null) {
      return DailyPuzzleEmptyView(
        state: dailyState,
        isDark: isDark,
        onPrevious: _previousDay,
        onNext: _nextDay,
        onGoToToday: _goToToday,
      );
    }

    return _buildPlayingView(context, dailyState, puzzleState, isDark);
  }

  Widget _buildPlayingView(
    BuildContext context,
    DailyPuzzleState dailyState,
    PuzzleSolveState puzzleState,
    bool isDark,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth - 16;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Date navigation with puzzle info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              children: [
                DateNavigationHeader(
                  selectedDate: dailyState.selectedDate,
                  isToday: dailyState.isToday,
                  isDark: isDark,
                  onPrevious: _previousDay,
                  onNext: _nextDay,
                ),
                const SizedBox(height: 4),
                _buildPuzzleInfo(dailyState, isDark),
              ],
            ),
          ),

          // Side to move
          _buildSideToMove(dailyState, isDark),

          // Chessboard
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Stack(
              children: [
                _buildChessboard(ref, puzzleState, boardSize),
                if (puzzleState.markerType != PuzzleMarkerType.none &&
                    puzzleState.markerSquare != null)
                  PuzzleMarkerOverlay(
                    markerType: puzzleState.markerType,
                    markerSquare: puzzleState.markerSquare!,
                    orientation: puzzleState.orientation,
                    boardSize: boardSize,
                  ),
              ],
            ),
          ),

          // Feedback
          PuzzleFeedbackBanner(puzzleState: puzzleState),

          // Instructions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              getInstructions(puzzleState.state),
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Claim reward button
          if (puzzleState.state == PuzzleState.completed)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => ref.read(dailyPuzzleProvider.notifier).markSolved(),
                icon: const Icon(Icons.check),
                label: const Text('Claim Reward'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildPuzzleInfo(DailyPuzzleState dailyState, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          dailyState.puzzle!.theme.displayName,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white70 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star, size: 14, color: Colors.amber.shade600),
              const SizedBox(width: 4),
              Text(
                '${dailyState.puzzle!.rating}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSideToMove(DailyPuzzleState dailyState, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dailyState.puzzle!.sideToMove == Side.white ? Colors.white : Colors.black,
              border: Border.all(color: Colors.grey),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${dailyState.puzzle!.sideToMove == Side.white ? "White" : "Black"} to move',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
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
      return Chessboard(
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
            _playMoveSound(move, state.currentFen);
            notifier.makeMove(move);
          },
          onPromotionSelection: (role) {},
        ),
      );
    } else {
      return Chessboard.fixed(
        size: boardSize,
        settings: settings,
        orientation: state.orientation,
        fen: state.currentFen,
        lastMove: state.lastMove,
      );
    }
  }
}
