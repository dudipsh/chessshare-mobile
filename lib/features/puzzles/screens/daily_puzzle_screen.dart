import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../models/puzzle.dart';
import '../providers/daily_puzzle_provider.dart';
import '../providers/puzzle_provider.dart';
import 'puzzle/puzzle_board_settings.dart';
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
          // Go to Today button (when not viewing today)
          if (!dailyState.isToday)
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: () {
                _puzzleLoaded = false;
                ref.read(dailyPuzzleProvider.notifier).goToToday();
              },
              tooltip: 'Go to Today',
            ),
          // Streak indicator
          if (dailyState.streak > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    '${dailyState.streak}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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
      return _buildSolvedView(context, dailyState, isDark);
    }

    if (dailyState.puzzle == null) {
      return _buildNoPuzzleView(context, isDark);
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth - 16;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Date navigation header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                // Previous day button
                IconButton(
                  onPressed: () {
                    _puzzleLoaded = false;
                    ref.read(dailyPuzzleProvider.notifier).previousDay();
                  },
                  icon: const Icon(Icons.chevron_left, size: 28),
                  tooltip: 'Previous day',
                ),
                // Date and puzzle info
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _formatDate(dailyState.selectedDate),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (dailyState.isToday)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Today',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Next day button (disabled if today)
                IconButton(
                  onPressed: dailyState.isToday
                      ? null
                      : () {
                          _puzzleLoaded = false;
                          ref.read(dailyPuzzleProvider.notifier).nextDay();
                        },
                  icon: Icon(
                    Icons.chevron_right,
                    size: 28,
                    color: dailyState.isToday
                        ? (isDark ? Colors.white24 : Colors.grey.shade300)
                        : null,
                  ),
                  tooltip: 'Next day',
                ),
              ],
            ),
          ),

          // Side to move indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dailyState.puzzle!.sideToMove == Side.white
                        ? Colors.white
                        : Colors.black,
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
          ),

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
          if (puzzleState.feedback != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getFeedbackColor(puzzleState.state),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getFeedbackIcon(puzzleState.state),
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      puzzleState.feedback!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Instructions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _getInstructions(puzzleState.state),
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Completed buttons
          if (puzzleState.state == PuzzleState.completed) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(dailyPuzzleProvider.notifier).markSolved();
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Claim Reward'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildSolvedView(BuildContext context, DailyPuzzleState state, bool isDark) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Date navigation for solved view too
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      _puzzleLoaded = false;
                      ref.read(dailyPuzzleProvider.notifier).previousDay();
                    },
                    icon: const Icon(Icons.chevron_left, size: 28),
                  ),
                  Text(
                    _formatDate(state.selectedDate),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (state.isToday)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: state.isToday
                        ? null
                        : () {
                            _puzzleLoaded = false;
                            ref.read(dailyPuzzleProvider.notifier).nextDay();
                          },
                    icon: Icon(
                      Icons.chevron_right,
                      size: 28,
                      color: state.isToday
                          ? (isDark ? Colors.white24 : Colors.grey.shade300)
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 80,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                state.isToday ? "Today's Puzzle Complete!" : "Puzzle Solved!",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (state.streak > 0 && state.isToday) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      '${state.streak} day streak!',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Text(
                state.isToday
                    ? 'Come back tomorrow for a new challenge'
                    : 'You solved this puzzle',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Show "Go to Today" button if not viewing today
              if (!state.isToday)
                ElevatedButton.icon(
                  onPressed: () {
                    _puzzleLoaded = false;
                    ref.read(dailyPuzzleProvider.notifier).goToToday();
                  },
                  icon: const Icon(Icons.today),
                  label: const Text("Go to Today's Puzzle"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 48),
                  ),
                ),
              if (!state.isToday) const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.pushNamed('puzzles'),
                icon: const Icon(Icons.extension),
                label: const Text('Practice Game Puzzles'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(200, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoPuzzleView(BuildContext context, bool isDark) {
    final dailyState = ref.watch(dailyPuzzleProvider);

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Date navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      _puzzleLoaded = false;
                      ref.read(dailyPuzzleProvider.notifier).previousDay();
                    },
                    icon: const Icon(Icons.chevron_left, size: 28),
                  ),
                  Text(
                    _formatDate(dailyState.selectedDate),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (dailyState.isToday)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: dailyState.isToday
                        ? null
                        : () {
                            _puzzleLoaded = false;
                            ref.read(dailyPuzzleProvider.notifier).nextDay();
                          },
                    icon: Icon(
                      Icons.chevron_right,
                      size: 28,
                      color: dailyState.isToday
                          ? (isDark ? Colors.white24 : Colors.grey.shade300)
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Icon(
                Icons.extension_off,
                size: 80,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
              const SizedBox(height: 24),
              const Text(
                'No Puzzle Available',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Import games to generate personalized puzzles',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (!dailyState.isToday) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    _puzzleLoaded = false;
                    ref.read(dailyPuzzleProvider.notifier).goToToday();
                  },
                  icon: const Icon(Icons.today),
                  label: const Text("Go to Today's Puzzle"),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
                onPressed: () => context.pushNamed('games'),
                child: const Text('Import Games'),
              ),
            ],
          ),
        ),
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

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
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

  IconData _getFeedbackIcon(PuzzleState state) {
    switch (state) {
      case PuzzleState.correct:
      case PuzzleState.completed:
        return Icons.check;
      case PuzzleState.incorrect:
        return Icons.close;
      default:
        return Icons.info;
    }
  }

  String _getInstructions(PuzzleState state) {
    switch (state) {
      case PuzzleState.ready:
        return 'Loading puzzle...';
      case PuzzleState.playing:
        return 'Find the best move';
      case PuzzleState.correct:
        return 'Great! Keep going...';
      case PuzzleState.incorrect:
        return 'Try again';
      case PuzzleState.completed:
        return 'Puzzle solved! Claim your reward.';
    }
  }
}
