import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/analyzed_move.dart';
import '../models/chess_game.dart';
import '../models/game_review.dart';
import '../models/move_classification.dart';
import '../providers/game_review_provider.dart';

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

    // Rebuild position from moves
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
          case 'q':
            promotion = Role.queen;
            break;
          case 'r':
            promotion = Role.rook;
            break;
          case 'b':
            promotion = Role.bishop;
            break;
          case 'n':
            promotion = Role.knight;
            break;
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
      appBar: AppBar(
        title: Text(
          'vs ${widget.game.opponentUsername}',
          style: const TextStyle(fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_vert),
            onPressed: () {
              setState(() {
                _orientation = _orientation == Side.white ? Side.black : Side.white;
              });
            },
            tooltip: 'Flip board',
          ),
        ],
      ),
      body: _buildBody(state, boardSize, isDark),
    );
  }

  Widget _buildBody(GameReviewState state, double boardSize, bool isDark) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.isAnalyzing) {
      return _buildAnalyzingView(state);
    }

    if (state.error != null) {
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
              onPressed: () {
                ref.read(gameReviewProvider(_userId).notifier).analyzeGame(widget.game);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.review == null) {
      return const Center(child: Text('No review available'));
    }

    return Column(
      children: [
        // Accuracy summary
        _buildAccuracySummary(state.review!, isDark),

        // Chess board with markers
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Stack(
            children: [
              _buildChessboard(state, boardSize),
              // Move marker overlay
              if (state.currentMove != null)
                _buildMoveMarker(state, boardSize),
            ],
          ),
        ),

        // Current move info
        if (state.currentMove != null)
          _buildMoveInfo(state.currentMove!, isDark),

        // Move navigation strip
        Expanded(
          child: _buildMoveStrip(state, isDark),
        ),

        // Navigation controls
        _buildNavigationControls(state),

        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }

  Widget _buildAnalyzingView(GameReviewState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                value: state.analysisProgress,
                strokeWidth: 8,
                backgroundColor: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '${(state.analysisProgress * 100).toInt()}%',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              state.analysisMessage ?? 'Analyzing...',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccuracySummary(GameReview review, bool isDark) {
    final playerSummary = review.playerSummary;
    final opponentSummary = review.opponentSummary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          // Player accuracy
          Expanded(
            child: _buildPlayerAccuracy(
              username: 'You',
              accuracy: playerSummary?.accuracy ?? 0,
              isPlayer: true,
              summary: playerSummary,
            ),
          ),
          // VS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'vs',
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          // Opponent accuracy
          Expanded(
            child: _buildPlayerAccuracy(
              username: widget.game.opponentUsername,
              accuracy: opponentSummary?.accuracy ?? 0,
              isPlayer: false,
              summary: opponentSummary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerAccuracy({
    required String username,
    required double accuracy,
    required bool isPlayer,
    AccuracySummary? summary,
  }) {
    return Column(
      crossAxisAlignment: isPlayer ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          username,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isPlayer ? AppColors.primary : null,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: isPlayer ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            Text(
              '${accuracy.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _getAccuracyColor(accuracy),
              ),
            ),
            const SizedBox(width: 8),
            // Mini summary icons
            if (summary != null) ...[
              if (summary.brilliant > 0)
                _buildMiniIcon(MoveClassification.brilliant, summary.brilliant),
              if (summary.blunder > 0)
                _buildMiniIcon(MoveClassification.blunder, summary.blunder),
              if (summary.mistake > 0)
                _buildMiniIcon(MoveClassification.mistake, summary.mistake),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMiniIcon(MoveClassification classification, int count) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: classification.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(classification.icon, size: 12, color: classification.color),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: classification.color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 95) return MoveClassification.brilliant.color;
    if (accuracy >= 85) return MoveClassification.best.color;
    if (accuracy >= 75) return MoveClassification.good.color;
    if (accuracy >= 60) return MoveClassification.inaccuracy.color;
    if (accuracy >= 45) return MoveClassification.mistake.color;
    return MoveClassification.blunder.color;
  }

  Widget _buildChessboard(GameReviewState state, double boardSize) {
    return Chessboard.fixed(
      size: boardSize,
      settings: ChessboardSettings(
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
        showValidMoves: false,
        showLastMove: true,
        animationDuration: const Duration(milliseconds: 150),
      ),
      orientation: _orientation,
      fen: _position.fen,
      lastMove: state.currentMove != null ? _parseLastMove(state.currentMove!) : null,
    );
  }

  NormalMove? _parseLastMove(AnalyzedMove move) {
    final uci = move.uci;
    if (uci.length < 4) return null;
    try {
      final from = Square.fromName(uci.substring(0, 2));
      final to = Square.fromName(uci.substring(2, 4));

      Role? promotion;
      if (uci.length > 4) {
        switch (uci[4].toLowerCase()) {
          case 'q':
            promotion = Role.queen;
            break;
          case 'r':
            promotion = Role.rook;
            break;
          case 'b':
            promotion = Role.bishop;
            break;
          case 'n':
            promotion = Role.knight;
            break;
        }
      }

      return NormalMove(from: from, to: to, promotion: promotion);
    } catch (e) {
      return null;
    }
  }

  Widget _buildMoveMarker(GameReviewState state, double boardSize) {
    final move = state.currentMove!;
    if (move.classification == MoveClassification.none) return const SizedBox.shrink();

    final squareSize = boardSize / 8;
    final uci = move.uci;
    if (uci.length < 4) return const SizedBox.shrink();

    try {
      final toSquare = Square.fromName(uci.substring(2, 4));
      final file = toSquare.file;
      final rank = toSquare.rank;

      double left;
      double top;

      if (_orientation == Side.black) {
        left = (7 - file) * squareSize;
        top = rank * squareSize;
      } else {
        left = file * squareSize;
        top = (7 - rank) * squareSize;
      }

      return Positioned(
        left: left,
        top: top,
        child: SizedBox(
          width: squareSize,
          height: squareSize,
          child: _buildClassificationMarker(move.classification, squareSize),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildClassificationMarker(MoveClassification classification, double size) {
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        width: size * 0.35,
        height: size * 0.35,
        margin: EdgeInsets.all(size * 0.05),
        decoration: BoxDecoration(
          color: classification.color,
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
          classification.icon,
          size: size * 0.22,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMoveInfo(AnalyzedMove move, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: move.classification.color.withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(color: move.classification.color.withValues(alpha: 0.3)),
          bottom: BorderSide(color: move.classification.color.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          // Classification badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: move.classification.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(move.classification.icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  move.classification.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Move notation
          Text(
            move.displayString,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Best move suggestion if different
          if (move.bestMove != null && move.bestMove != move.san && !move.classification.isGood)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Best: ${move.bestMove}',
                  style: TextStyle(
                    fontSize: 14,
                    color: MoveClassification.best.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  move.evalAfterDisplay,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMoveStrip(GameReviewState state, bool isDark) {
    if (state.review == null || state.review!.moves.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: state.review!.moves.length,
      itemBuilder: (context, index) {
        final move = state.review!.moves[index];
        final isSelected = index == state.currentMoveIndex - 1;

        return GestureDetector(
          onTap: () {
            ref.read(gameReviewProvider(_userId).notifier).goToMove(index + 1);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? Colors.grey[700] : Colors.grey[200])
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Move number
                SizedBox(
                  width: 40,
                  child: Text(
                    move.displayString.split(' ').first,
                    style: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ),
                // Move with classification
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: move.classification.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: move.classification.color.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        move.classification.icon,
                        size: 14,
                        color: move.classification.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        move.san,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: move.classification.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Eval
                Text(
                  move.evalAfterDisplay,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigationControls(GameReviewState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: () {
              ref.read(gameReviewProvider(_userId).notifier).goToStart();
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              ref.read(gameReviewProvider(_userId).notifier).previousMove();
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${state.currentMoveIndex}/${state.review?.moves.length ?? 0}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              ref.read(gameReviewProvider(_userId).notifier).nextMove();
            },
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: () {
              ref.read(gameReviewProvider(_userId).notifier).goToEnd();
            },
          ),
        ],
      ),
    );
  }
}
