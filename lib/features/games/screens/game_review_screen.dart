import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../core/database/local_database.dart';
import '../../../core/providers/board_settings_provider.dart';
import '../../../core/widgets/board_settings_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chess_game.dart';
import '../models/move_classification.dart';
import '../providers/game_review_provider.dart';
import '../widgets/move_markers.dart';
import 'game_review/accuracy_summary.dart';
import 'game_review/action_buttons.dart';
import 'game_review/analyzing_view.dart';
import 'game_review/move_info_panel.dart';
import 'game_review/moves_list.dart';
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
  Chess _position = Chess.initial;
  bool _isFreeExploration = false;
  Chess? _explorationPosition;

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

  void _updatePosition(GameReviewState state) {
    if (state.review == null) {
      _position = Chess.initial;
      return;
    }

    _position = Chess.initial;
    for (var i = 0; i < state.currentMoveIndex && i < state.review!.moves.length; i++) {
      final move = state.review!.moves[i];
      try {
        final parsedMove = _parseUciMove(move.uci);
        if (parsedMove != null) {
          _position = _position.play(parsedMove) as Chess;
        }
      } catch (e) {
        break;
      }
    }
  }

  NormalMove? _parseUciMove(String uci) {
    if (uci.length < 4) return null;
    try {
      final from = Square.fromName(uci.substring(0, 2));
      final to = Square.fromName(uci.substring(2, 4));
      Role? promotion;
      if (uci.length > 4) {
        switch (uci[4].toLowerCase()) {
          case 'q': promotion = Role.queen; break;
          case 'r': promotion = Role.rook; break;
          case 'b': promotion = Role.bishop; break;
          case 'n': promotion = Role.knight; break;
        }
      }
      return NormalMove(from: from, to: to, promotion: promotion);
    } catch (e) {
      return null;
    }
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
    _updatePosition(state);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth - 16;

    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildBody(state, boardSize, isDark),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text('vs ${widget.game.opponentUsername}', style: const TextStyle(fontSize: 17)),
      actions: [
        IconButton(
          icon: Icon(
            _isFreeExploration ? Icons.explore : Icons.explore_outlined,
            color: _isFreeExploration ? Theme.of(context).primaryColor : null,
          ),
          onPressed: _toggleExploration,
          tooltip: _isFreeExploration ? 'Exit free mode' : 'Free exploration',
        ),
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

  void _toggleExploration() {
    setState(() {
      _isFreeExploration = !_isFreeExploration;
      if (_isFreeExploration) {
        _explorationPosition = Chess.fromSetup(Setup.parseFen(_position.fen));
      } else {
        _explorationPosition = null;
      }
    });
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

  Widget _buildBody(GameReviewState state, double boardSize, bool isDark) {
    if (state.isLoading) return const Center(child: CircularProgressIndicator());

    if (state.isAnalyzing) {
      return AnalyzingView(
        progress: state.analysisProgress,
        message: state.analysisMessage,
      );
    }

    if (state.error != null) return _buildErrorView(state);
    if (state.review == null) return const Center(child: Text('No review available'));

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
            evalCp: state.currentMove?.evalAfter,
            width: boardSize,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Stack(
            children: [
              _buildChessboard(state, boardSize),
              if (state.currentMove != null) _buildMoveMarker(state, boardSize),
            ],
          ),
        ),
        if (state.currentMove != null)
          MoveInfoPanel(move: state.currentMove!, isDark: isDark),
        Expanded(
          child: MovesList(
            moves: state.review!.moves,
            currentMoveIndex: state.currentMoveIndex,
            isDark: isDark,
            onMoveSelected: (index) {
              ref.read(gameReviewProvider(_userId).notifier).goToMove(index);
            },
          ),
        ),
        NavigationControls(
          currentMoveIndex: state.currentMoveIndex,
          totalMoves: state.review?.moves.length ?? 0,
          onFirst: () => ref.read(gameReviewProvider(_userId).notifier).goToStart(),
          onPrevious: () => ref.read(gameReviewProvider(_userId).notifier).previousMove(),
          onNext: () => ref.read(gameReviewProvider(_userId).notifier).nextMove(),
          onLast: () => ref.read(gameReviewProvider(_userId).notifier).goToEnd(),
        ),
        ReviewActionButtons(
          mistakesCount: _getMistakesCount(state),
          onPractice: () => _navigateToPracticeMistakes(state),
          onPlayEngine: () => _navigateToPlayVsStockfish(),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
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

  Widget _buildChessboard(GameReviewState state, double boardSize) {
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
      showValidMoves: _isFreeExploration,
      showLastMove: true,
      animationDuration: const Duration(milliseconds: 150),
      dragFeedbackScale: 2.0,
      dragFeedbackOffset: const Offset(0, -1),
    );

    final displayPosition = _isFreeExploration && _explorationPosition != null
        ? _explorationPosition!
        : _position;

    if (_isFreeExploration && _explorationPosition != null) {
      return Chessboard(
        size: boardSize,
        settings: settings,
        orientation: _orientation,
        fen: displayPosition.fen,
        lastMove: null,
        game: GameData(
          playerSide: PlayerSide.both,
          sideToMove: displayPosition.turn == Side.white ? Side.white : Side.black,
          validMoves: _getValidMoves(displayPosition),
          promotionMove: null,
          onMove: (move, {isDrop}) => _makeExplorationMove(move),
          onPromotionSelection: (role) {},
        ),
      );
    } else {
      return Chessboard.fixed(
        size: boardSize,
        settings: settings,
        orientation: _orientation,
        fen: displayPosition.fen,
        lastMove: state.currentMove != null ? _parseUciMove(state.currentMove!.uci) : null,
      );
    }
  }

  IMap<Square, ISet<Square>> _getValidMoves(Chess position) {
    final Map<Square, Set<Square>> moves = {};
    for (final entry in position.legalMoves.entries) {
      final from = entry.key;
      final toSquares = entry.value;
      if (toSquares.isNotEmpty) {
        moves[from] = toSquares.squares.toSet();
      }
    }
    return IMap(moves.map((k, v) => MapEntry(k, ISet(v))));
  }

  void _makeExplorationMove(NormalMove move) {
    if (_explorationPosition == null) return;
    try {
      final dcMove = NormalMove(from: move.from, to: move.to, promotion: move.promotion);
      final newPosition = _explorationPosition!.play(dcMove) as Chess;
      setState(() => _explorationPosition = newPosition);
    } catch (e) {
      // Invalid move, ignore
    }
  }

  Widget _buildMoveMarker(GameReviewState state, double boardSize) {
    final move = state.currentMove!;
    if (move.classification == MoveClassification.none) return const SizedBox.shrink();

    final squareSize = boardSize / 8;
    final markerSize = squareSize * 0.4;
    final uci = move.uci;
    if (uci.length < 4) return const SizedBox.shrink();

    try {
      final toSquare = Square.fromName(uci.substring(2, 4));
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
    } catch (e) {
      return const SizedBox.shrink();
    }
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

  void _navigateToPlayVsStockfish() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayVsStockfishScreen(
          startFen: _position.fen,
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
