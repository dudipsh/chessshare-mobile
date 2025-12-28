import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../core/providers/board_settings_provider.dart';
import '../../../core/providers/captured_pieces_provider.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/widgets/board_settings_factory.dart';
import '../../../core/widgets/chess_board_shell.dart';
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

      ref.read(audioServiceProvider).playMoveWithHaptic(
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
          const SizedBox(height: 4),
          // Date navigation
          DateNavigationHeader(
            selectedDate: dailyState.selectedDate,
            isToday: dailyState.isToday,
            isDark: isDark,
            onPrevious: _previousDay,
            onNext: _nextDay,
          ),

          // Puzzle info bar (side to move + rating)
          _buildPuzzleInfoBar(dailyState, isDark),

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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            _buildClaimRewardButton(isDark),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildClaimRewardButton(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => ref.read(dailyPuzzleProvider.notifier).markSolved(),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.withValues(alpha: 0.2),
                    Colors.orange.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events,
                    size: 20,
                    color: Colors.amber.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Claim Reward',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPuzzleInfoBar(DailyPuzzleState dailyState, bool isDark) {
    final sideToMove = dailyState.puzzle!.sideToMove;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Side to move indicator
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: sideToMove == Side.white ? Colors.white : Colors.grey.shade800,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${sideToMove == Side.white ? "White" : "Black"} to move',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          // Theme badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              dailyState.puzzle!.theme.displayName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Rating badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, size: 12, color: Colors.amber.shade700),
                const SizedBox(width: 4),
                Text(
                  '${dailyState.puzzle!.rating}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChessboard(WidgetRef ref, PuzzleSolveState state, double boardSize) {
    final notifier = ref.read(puzzleSolveProvider.notifier);
    final boardSettings = ref.watch(boardSettingsProvider);
    final settings = BoardSettingsFactory.create(boardSettings: boardSettings);
    final isPlayable = state.state == PuzzleState.playing;
    final fen = state.currentFen;

    // Update captured pieces
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(capturedPiecesProvider.notifier).updateFromFen(fen);
    });

    Widget chessBoard;
    if (isPlayable) {
      chessBoard = Chessboard(
        size: boardSize,
        settings: settings,
        orientation: state.orientation,
        fen: fen,
        lastMove: state.lastMove,
        game: GameData(
          playerSide: state.orientation == Side.white ? PlayerSide.white : PlayerSide.black,
          sideToMove: notifier.sideToMove,
          validMoves: state.validMoves,
          promotionMove: null,
          onMove: (move, {isDrop}) {
            notifier.makeMove(move);
            _playMoveSound(move, fen);
          },
          onPromotionSelection: (role) {},
        ),
      );
    } else {
      chessBoard = Chessboard.fixed(
        size: boardSize,
        settings: settings,
        orientation: state.orientation,
        fen: fen,
        lastMove: state.lastMove,
      );
    }

    return ChessBoardShell(
      board: chessBoard,
      orientation: state.orientation,
      fen: fen,
      showCapturedPieces: true,
      padding: EdgeInsets.zero,
    );
  }
}
