import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/local_database.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/widgets/board_settings_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chess_game.dart';
import '../models/move_classification.dart';
import '../providers/exploration_mode_provider.dart';
import '../providers/game_review_provider.dart';
import 'game_review/accuracy_summary.dart';
import 'game_review/action_buttons.dart';
import 'game_review/analyzing_view.dart';
import 'game_review/exploration_bar.dart';
import 'game_review/move_info_panel.dart';
import 'game_review/move_strip.dart';
import 'game_review/navigation_controls.dart';
import 'game_review/review_chessboard.dart';
import 'game_review/review_error_view.dart';
import 'game_review/review_move_marker.dart';
import 'game_review/static_evaluation_bar.dart';
import 'play_vs_stockfish_screen.dart';
import 'practice_mistakes_screen.dart';

class GameReviewScreen extends ConsumerStatefulWidget {
  final ChessGame game;

  const GameReviewScreen({super.key, required this.game});

  @override
  ConsumerState<GameReviewScreen> createState() => _GameReviewScreenState();
}

class _GameReviewScreenState extends ConsumerState<GameReviewScreen> {
  late String _userId;
  Side _orientation = Side.white;

  @override
  void initState() {
    super.initState();
    _orientation = widget.game.playerColor == 'white' ? Side.white : Side.black;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _userId = ref.read(authProvider).profile?.id ?? '';
      if (_userId.isNotEmpty) {
        ref.read(gameReviewProvider(_userId).notifier).loadReview(widget.game);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).profile?.id ?? '';
    if (userId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to review games')),
      );
    }

    final state = ref.watch(gameReviewProvider(userId));
    final explorationState = ref.watch(explorationModeProvider);

    // Sync exploration position with game review when not exploring
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!explorationState.isExploring && state.review != null) {
        ref.read(explorationModeProvider.notifier).setPosition(
          state.fen,
          state.currentMoveIndex,
        );
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth - 16;

    return Scaffold(
      appBar: _buildAppBar(context, state),
      body: _buildBody(state, explorationState, boardSize, isDark),
    );
  }

  AppBar _buildAppBar(BuildContext context, GameReviewState state) {
    return AppBar(
      title: Text('vs ${widget.game.opponentUsername}', style: const TextStyle(fontSize: 17)),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _showSettings(context),
          tooltip: 'Board settings',
        ),
        if (kDebugMode) _buildDebugMenu(),
      ],
    );
  }

  PopupMenuButton<String> _buildDebugMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) => _handleDebugAction(value, _userId),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'clear_analysis',
          child: Row(
            children: [Icon(Icons.delete_outline, size: 20), SizedBox(width: 8), Text('Clear Analysis')],
          ),
        ),
        const PopupMenuItem(
          value: 're_analyze',
          child: Row(
            children: [Icon(Icons.refresh, size: 20), SizedBox(width: 8), Text('Re-analyze')],
          ),
        ),
      ],
    );
  }

  void _showSettings(BuildContext context) {
    showBoardSettingsSheet(
      context: context,
      ref: ref,
      onFlipBoard: () {
        setState(() {
          _orientation = _orientation == Side.white ? Side.black : Side.white;
        });
      },
    );
  }

  Widget _buildBody(GameReviewState state, ExplorationState explorationState, double boardSize, bool isDark) {
    if (state.isLoading) return const Center(child: CircularProgressIndicator());

    if (state.isAnalyzing) {
      return AnalyzingView(progress: state.analysisProgress, message: state.analysisMessage);
    }

    if (state.error != null) {
      return ReviewErrorView(
        error: state.error!,
        onRetry: () => ref.read(gameReviewProvider(_userId).notifier).analyzeGame(widget.game),
      );
    }

    if (state.review == null) return const Center(child: Text('No review available'));

    final evalCp = explorationState.isExploring
        ? explorationState.evalCp
        : state.currentMove?.evalAfter;

    return Column(
      children: [
        AccuracySummary(
          review: state.review!,
          opponentUsername: widget.game.opponentUsername,
          isDark: isDark,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: StaticEvaluationBar(
            evalCp: evalCp,
            width: boardSize,
            isAnalyzing: explorationState.isExploring && explorationState.isEvaluating,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Stack(
            children: [
              ReviewChessboard(
                state: state,
                explorationState: explorationState,
                boardSize: boardSize,
                orientation: _orientation,
                onMove: (move) => _onBoardMove(move, state),
              ),
              if (state.currentMove != null && !explorationState.isExploring)
                ReviewMoveMarker(
                  move: state.currentMove!,
                  boardSize: boardSize,
                  orientation: _orientation,
                ),
            ],
          ),
        ),
        // B3: Reordered - Move history first, then the info panel
        _buildMoveStrip(state, explorationState, isDark),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // B3: Removed BestMoveHint ("best tap to explore" bar)
                if (explorationState.isExploring)
                  ExplorationBar(explorationState: explorationState, isDark: isDark),
                // B3: MoveInfoPanel (the "nice bar") now comes after move history
                if (state.currentMove != null && !explorationState.isExploring)
                  MoveInfoPanel(move: state.currentMove!, isDark: isDark),
              ],
            ),
          ),
        ),
        _buildNavigationControls(state, explorationState),
        ReviewActionButtons(
          mistakesCount: _getMistakesCount(state),
          onPractice: () => _navigateToPracticeMistakes(state),
          onPlayEngine: () => _navigateToPlayVsStockfish(state, explorationState),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }

  Widget _buildMoveStrip(GameReviewState state, ExplorationState explorationState, bool isDark) {
    return MoveStrip(
      moves: state.review!.moves,
      currentMoveIndex: explorationState.isExploring
          ? (explorationState.originalMoveIndex ?? state.currentMoveIndex)
          : state.currentMoveIndex,
      isDark: isDark,
      onMoveSelected: (index) {
        if (explorationState.isExploring) {
          ref.read(explorationModeProvider.notifier).returnToGame();
        }
        ref.read(gameReviewProvider(_userId).notifier).goToMove(index);
        if (index > 0) _playSoundForMoveIndex(index);
      },
    );
  }

  Widget _buildNavigationControls(GameReviewState state, ExplorationState explorationState) {
    return NavigationControls(
      currentMoveIndex: state.currentMoveIndex,
      totalMoves: state.review?.moves.length ?? 0,
      onFirst: () {
        if (explorationState.isExploring) ref.read(explorationModeProvider.notifier).returnToGame();
        ref.read(gameReviewProvider(_userId).notifier).goToStart();
      },
      onPrevious: () {
        if (explorationState.isExploring) {
          ref.read(explorationModeProvider.notifier).undoMove();
        } else {
          final currentIdx = ref.read(gameReviewProvider(_userId)).currentMoveIndex;
          ref.read(gameReviewProvider(_userId).notifier).previousMove();
          if (currentIdx > 1) _playSoundForMoveIndex(currentIdx - 1);
        }
      },
      onNext: () {
        if (explorationState.isExploring) ref.read(explorationModeProvider.notifier).returnToGame();
        final currentIdx = ref.read(gameReviewProvider(_userId)).currentMoveIndex;
        final totalMoves = ref.read(gameReviewProvider(_userId)).review?.moves.length ?? 0;
        ref.read(gameReviewProvider(_userId).notifier).nextMove();
        if (currentIdx < totalMoves) _playSoundForMoveIndex(currentIdx + 1);
      },
      onLast: () {
        if (explorationState.isExploring) ref.read(explorationModeProvider.notifier).returnToGame();
        final totalMoves = ref.read(gameReviewProvider(_userId)).review?.moves.length ?? 0;
        ref.read(gameReviewProvider(_userId).notifier).goToEnd();
        if (totalMoves > 0) _playSoundForMoveIndex(totalMoves);
      },
    );
  }

  // Sound helpers
  void _playMoveSound(NormalMove move, String fen) {
    try {
      final position = Chess.fromSetup(Setup.parseFen(fen));
      final san = position.makeSan(move).$2;
      _playSoundFromSan(san);
    } catch (_) {}
  }

  void _playSoundFromSan(String san) {
    ref.read(audioServiceProvider).playMoveWithHaptic(
      isCapture: san.contains('x'),
      isCheck: san.contains('+'),
      isCastle: san == 'O-O' || san == 'O-O-O',
      isCheckmate: san.contains('#'),
    );
  }

  void _playSoundForMoveIndex(int moveIndex) {
    final state = ref.read(gameReviewProvider(_userId));
    if (state.review == null || moveIndex <= 0 || moveIndex > state.review!.moves.length) return;
    _playSoundFromSan(state.review!.moves[moveIndex - 1].san);
  }

  void _onBoardMove(NormalMove move, GameReviewState state) {
    _playMoveSound(move, state.fen);

    String? expectedUci;
    if (state.currentMoveIndex < (state.review?.moves.length ?? 0)) {
      expectedUci = state.review!.moves[state.currentMoveIndex].uci;
    }

    final isExplorationMove = ref.read(explorationModeProvider.notifier).makeMove(
      move,
      expectedUci: expectedUci,
    );

    if (!isExplorationMove && expectedUci != null) {
      ref.read(gameReviewProvider(_userId).notifier).nextMove();
    }
  }

  // Navigation helpers
  int _getMistakesCount(GameReviewState state) {
    if (state.review == null) return 0;
    return state.review!.moves
        .where((m) => m.color == widget.game.playerColor)
        .where((m) => m.classification.isPuzzleWorthy)
        .length;
  }

  void _navigateToPracticeMistakes(GameReviewState state) {
    if (state.review == null) return;

    final mistakes = state.review!.moves
        .where((m) => m.color == widget.game.playerColor)
        .where((m) => m.classification.isPuzzleWorthy)
        .toList();

    if (mistakes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No mistakes to practice!')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PracticeMistakesScreen(
          mistakes: mistakes,
          game: widget.game,
          reviewId: state.review!.id,
        ),
      ),
    );
  }

  void _navigateToPlayVsStockfish(GameReviewState state, ExplorationState explorationState) {
    final fen = explorationState.isExploring ? explorationState.fen : state.fen;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayVsStockfishScreen(
          startFen: fen,
          playerColor: widget.game.playerColor == 'white' ? Side.white : Side.black,
        ),
      ),
    );
  }

  Future<void> _handleDebugAction(String action, String userId) async {
    switch (action) {
      case 'clear_analysis':
        await LocalDatabase.deleteGameReviewByGameId(userId, widget.game.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analysis data cleared')));
          Navigator.pop(context);
        }
        break;
      case 're_analyze':
        await LocalDatabase.deleteGameReviewByGameId(userId, widget.game.id);
        if (mounted) {
          ref.read(gameReviewProvider(userId).notifier).analyzeGame(widget.game);
        }
        break;
    }
  }
}
