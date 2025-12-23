import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../core/database/local_database.dart';
import '../../../core/providers/board_settings_provider.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/widgets/board_settings_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chess_game.dart';
import '../models/move_classification.dart';
import '../providers/exploration_mode_provider.dart';
import '../providers/game_review_provider.dart';
import '../utils/chess_position_utils.dart';
import '../widgets/move_markers.dart';
import 'game_review/accuracy_summary.dart';
import 'game_review/action_buttons.dart';
import 'game_review/analyzing_view.dart';
import 'game_review/move_info_panel.dart';
import 'game_review/move_strip.dart';
import 'game_review/navigation_controls.dart';
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth - 16;

    return Scaffold(
      appBar: _buildAppBar(context, state, explorationState),
      body: _buildBody(state, explorationState, boardSize, isDark),
    );
  }

  AppBar _buildAppBar(BuildContext context, GameReviewState state, ExplorationState explorationState) {
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
      return AnalyzingView(
        progress: state.analysisProgress,
        message: state.analysisMessage,
      );
    }

    if (state.error != null) return _buildErrorView(state);
    if (state.review == null) return const Center(child: Text('No review available'));

    // Get evaluation - use exploration eval when exploring, otherwise game analysis eval
    final evalCp = explorationState.isExploring
        ? explorationState.evalCp // Live eval during exploration
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
              _buildChessboard(state, explorationState, boardSize),
              if (state.currentMove != null && !explorationState.isExploring)
                _buildMoveMarker(state, boardSize),
            ],
          ),
        ),
        // Flexible area for move info, hints, and exploration bar
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show best move suggestion when not exploring
                if (state.currentMove != null && !explorationState.isExploring)
                  _buildBestMoveHint(state, isDark),
                // Show exploration indicator when exploring
                if (explorationState.isExploring)
                  _buildExplorationBar(explorationState, isDark),
                if (state.currentMove != null && !explorationState.isExploring)
                  MoveInfoPanel(move: state.currentMove!, isDark: isDark),
              ],
            ),
          ),
        ),
        MoveStrip(
          moves: state.review!.moves,
          currentMoveIndex: explorationState.isExploring
              ? (explorationState.originalMoveIndex ?? state.currentMoveIndex)
              : state.currentMoveIndex,
          isDark: isDark,
          onMoveSelected: (index) {
            // Exit exploration if active and go to selected move
            if (explorationState.isExploring) {
              ref.read(explorationModeProvider.notifier).returnToGame();
            }
            ref.read(gameReviewProvider(_userId).notifier).goToMove(index);
          },
        ),
        NavigationControls(
          currentMoveIndex: state.currentMoveIndex,
          totalMoves: state.review?.moves.length ?? 0,
          onFirst: () {
            if (explorationState.isExploring) {
              ref.read(explorationModeProvider.notifier).returnToGame();
            }
            ref.read(gameReviewProvider(_userId).notifier).goToStart();
          },
          onPrevious: () {
            if (explorationState.isExploring) {
              // Undo exploration move instead of going back in game
              ref.read(explorationModeProvider.notifier).undoMove();
            } else {
              ref.read(gameReviewProvider(_userId).notifier).previousMove();
            }
          },
          onNext: () {
            if (explorationState.isExploring) {
              ref.read(explorationModeProvider.notifier).returnToGame();
            }
            ref.read(gameReviewProvider(_userId).notifier).nextMove();
          },
          onLast: () {
            if (explorationState.isExploring) {
              ref.read(explorationModeProvider.notifier).returnToGame();
            }
            ref.read(gameReviewProvider(_userId).notifier).goToEnd();
          },
        ),
        ReviewActionButtons(
          mistakesCount: _getMistakesCount(state),
          onPractice: () => _navigateToPracticeMistakes(state),
          onPlayEngine: () => _navigateToPlayVsStockfish(state, explorationState),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }

  Widget _buildBestMoveHint(GameReviewState state, bool isDark) {
    final move = state.currentMove!;
    if (move.bestMove == null) return const SizedBox.shrink();

    // Only show if current move wasn't the best
    final isBestMove = move.classification == MoveClassification.best ||
                       move.classification == MoveClassification.brilliant ||
                       move.classification == MoveClassification.great;
    if (isBestMove) return const SizedBox.shrink();

    // Format best move with piece icon
    final isWhite = move.color == 'white';
    String formattedBestMove;
    if (move.bestMoveUci != null && move.bestMoveUci!.isNotEmpty && move.fen.isNotEmpty) {
      formattedBestMove = ChessPositionUtils.formatMoveWithIcon(
        move.bestMoveUci!,
        fen: move.fen,
        isWhite: isWhite,
      );
    } else {
      formattedBestMove = ChessPositionUtils.formatMoveWithIcon(
        move.bestMove!,
        fen: move.fen,
        isWhite: isWhite,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, size: 18, color: Colors.green[isDark ? 400 : 600]),
          const SizedBox(width: 8),
          Text(
            'Best: ',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Text(
            formattedBestMove,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green[isDark ? 400 : 700],
            ),
          ),
          const Spacer(),
          Text(
            'Tap to explore',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplorationBar(ExplorationState explorationState, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primary.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.explore, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            'Exploring',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
          if (explorationState.explorationMoves.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              '(${explorationState.explorationMoves.length} moves)',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              ref.read(explorationModeProvider.notifier).returnToGame();
            },
            icon: const Icon(Icons.undo, size: 16),
            label: const Text('Back to game'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(GameReviewState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Analysis failed', style: TextStyle(fontSize: 18, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Text(state.error!, style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ref.read(gameReviewProvider(_userId).notifier).analyzeGame(widget.game),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildChessboard(GameReviewState state, ExplorationState explorationState, double boardSize) {
    final boardSettings = ref.watch(boardSettingsProvider);
    final lightSquare = boardSettings.colorScheme.lightSquare;
    final darkSquare = boardSettings.colorScheme.darkSquare;
    final pieceAssets = boardSettings.pieceSet.pieceSet.assets;

    final settings = ChessboardSettings(
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
      showLastMove: !explorationState.isExploring,
      animationDuration: const Duration(milliseconds: 150),
      dragFeedbackScale: 2.0,
      dragFeedbackOffset: const Offset(0, -1),
    );

    // Always use interactive chessboard
    final fen = explorationState.isExploring
        ? explorationState.fen
        : state.fen;
    final validMoves = explorationState.validMoves;

    return Chessboard(
      size: boardSize,
      settings: settings,
      orientation: _orientation,
      fen: fen,
      lastMove: explorationState.isExploring ? null : state.lastMove,
      game: GameData(
        playerSide: PlayerSide.both,
        sideToMove: explorationState.sideToMove,
        validMoves: validMoves,
        promotionMove: null,
        onMove: (move, {isDrop}) => _onBoardMove(move, state),
        onPromotionSelection: (role) {},
      ),
    );
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

  void _onBoardMove(NormalMove move, GameReviewState state) {
    // Play move sound
    _playMoveSound(move, state.fen);

    // Get the expected next move from game history
    String? expectedUci;
    if (state.currentMoveIndex < (state.review?.moves.length ?? 0)) {
      expectedUci = state.review!.moves[state.currentMoveIndex].uci;
    }

    // Make the move in exploration provider
    final isExplorationMove = ref.read(explorationModeProvider.notifier).makeMove(
      move,
      expectedUci: expectedUci,
    );

    // If this was the game's next move, also advance the game review
    if (!isExplorationMove && expectedUci != null) {
      ref.read(gameReviewProvider(_userId).notifier).nextMove();
    }
  }

  Widget _buildMoveMarker(GameReviewState state, double boardSize) {
    final move = state.currentMove!;
    if (move.classification == MoveClassification.none) return const SizedBox.shrink();

    final squareSize = boardSize / 8;
    final markerSize = squareSize * 0.4;

    final toSquareName = ChessPositionUtils.getDestinationSquare(move.uci);
    if (toSquareName == null) return const SizedBox.shrink();

    final toSquare = ChessPositionUtils.parseSquare(toSquareName);
    if (toSquare == null) return const SizedBox.shrink();

    final file = toSquare.file;
    final rank = toSquare.rank;

    double x = _orientation == Side.black ? (7 - file).toDouble() : file.toDouble();
    double y = _orientation == Side.black ? rank.toDouble() : (7 - rank).toDouble();

    final left = x * squareSize + squareSize - markerSize * 1.1;
    final top = y * squareSize + markerSize * 0.1;

    return Positioned(
      left: left,
      top: top,
      child: MoveMarker(classification: move.classification, size: markerSize),
    );
  }

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
    // Use current position (could be exploration position)
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
