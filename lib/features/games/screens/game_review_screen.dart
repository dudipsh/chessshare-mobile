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
import '../models/analyzed_move.dart';
import '../models/chess_game.dart';
import '../models/game_review.dart';
import '../models/move_classification.dart';
import '../providers/game_review_provider.dart';
import '../widgets/move_markers.dart';
import 'practice_mistakes_screen.dart';
import 'play_vs_stockfish_screen.dart';

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
          // Free exploration toggle
          IconButton(
            icon: Icon(
              _isFreeExploration ? Icons.explore : Icons.explore_outlined,
              color: _isFreeExploration ? Theme.of(context).primaryColor : null,
            ),
            onPressed: () {
              setState(() {
                _isFreeExploration = !_isFreeExploration;
                if (_isFreeExploration) {
                  // Start exploration from current position
                  _explorationPosition = Chess.fromSetup(Setup.parseFen(_position.fen));
                } else {
                  // Reset exploration position
                  _explorationPosition = null;
                }
              });
            },
            tooltip: _isFreeExploration ? 'Exit free mode' : 'Free exploration',
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showBoardSettingsSheet(
                context: context,
                ref: ref,
                onFlipBoard: () {
                  setState(() {
                    _orientation = _orientation == Side.white ? Side.black : Side.white;
                  });
                },
              );
            },
            tooltip: 'Board settings',
          ),
          // Debug menu (only in debug mode)
          if (kDebugMode)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) => _handleDebugAction(value, userId),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear_analysis',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20),
                      SizedBox(width: 8),
                      Text('Clear Analysis'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 're_analyze',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20),
                      SizedBox(width: 8),
                      Text('Re-analyze'),
                    ],
                  ),
                ),
              ],
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

        // Evaluation bar above board
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: _buildStaticEvaluationBar(state, boardSize),
        ),

        // Chess board with markers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
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

        // Action buttons (Training Mode + Play vs Stockfish)
        _buildActionButtons(state, isDark),

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
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '${accuracy.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _getAccuracyColor(accuracy),
          ),
        ),
      ],
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

  /// Build a static evaluation bar based on the current move's evaluation
  Widget _buildStaticEvaluationBar(GameReviewState state, double boardSize) {
    // Get the evaluation from the current move (evalAfter represents eval after the move)
    int? evalCp;
    if (state.currentMove != null) {
      evalCp = state.currentMove!.evalAfter;
    }

    // Convert centipawns to normalized score (0.0 = black winning, 0.5 = equal, 1.0 = white winning)
    double normalizedScore = 0.5;
    if (evalCp != null) {
      // Use sigmoid-like function to map centipawns to 0-1 range
      // Clamp to reasonable bounds (-1000 to 1000 cp for display)
      final clampedCp = evalCp.clamp(-1000, 1000);
      // Map to 0-1 range with 0.5 as equal
      normalizedScore = 0.5 + (clampedCp / 2000);
      normalizedScore = normalizedScore.clamp(0.05, 0.95);
    }

    // Format evaluation string
    String evalString = '';
    if (evalCp != null) {
      if (evalCp.abs() >= 10000) {
        // Mate score
        final mateIn = ((10000 - evalCp.abs()) / 2).ceil();
        evalString = evalCp > 0 ? 'M$mateIn' : '-M$mateIn';
      } else {
        final pawns = evalCp / 100;
        if (pawns >= 0) {
          evalString = '+${pawns.toStringAsFixed(1)}';
        } else {
          evalString = pawns.toStringAsFixed(1);
        }
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: boardSize,
      height: 20,
      child: Row(
        children: [
          // White side evaluation label
          SizedBox(
            width: 40,
            child: Text(
              normalizedScore > 0.5 ? evalString : '',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // The evaluation bar
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  width: 0.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3.5),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final whiteWidth = constraints.maxWidth * normalizedScore;

                    return Stack(
                      children: [
                        // Black side (right/background)
                        Positioned.fill(
                          child: Container(color: Colors.grey.shade800),
                        ),
                        // White side (left)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          top: 0,
                          bottom: 0,
                          left: 0,
                          width: whiteWidth,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 2,
                                  offset: const Offset(1, 0),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          // Black side evaluation label
          SizedBox(
            width: 40,
            child: Text(
              normalizedScore < 0.5 ? evalString : '',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
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
        background: SolidColorChessboardBackground(
          lightSquare: lightSquare,
          darkSquare: darkSquare,
        ),
        whiteCoordBackground: SolidColorChessboardBackground(
          lightSquare: lightSquare,
          darkSquare: darkSquare,
          coordinates: true,
        ),
        blackCoordBackground: SolidColorChessboardBackground(
          lightSquare: lightSquare,
          darkSquare: darkSquare,
          coordinates: true,
          orientation: Side.black,
        ),
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

    // Use exploration position if in free mode, otherwise use review position
    final displayPosition = _isFreeExploration && _explorationPosition != null
        ? _explorationPosition!
        : _position;

    if (_isFreeExploration && _explorationPosition != null) {
      // Interactive board for free exploration
      return Chessboard(
        size: boardSize,
        settings: settings,
        orientation: _orientation,
        fen: displayPosition.fen,
        lastMove: null,
        game: GameData(
          playerSide: PlayerSide.both, // Allow both sides to move
          sideToMove: displayPosition.turn == Side.white ? Side.white : Side.black,
          validMoves: _getValidMoves(displayPosition),
          promotionMove: null,
          onMove: (move, {isDrop}) {
            _makeExplorationMove(move);
          },
          onPromotionSelection: (role) {},
        ),
      );
    } else {
      // Fixed board for normal review
      return Chessboard.fixed(
        size: boardSize,
        settings: settings,
        orientation: _orientation,
        fen: displayPosition.fen,
        lastMove: state.currentMove != null ? _parseLastMove(state.currentMove!) : null,
      );
    }
  }

  /// Get valid moves for the current position
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

  /// Make a move in exploration mode
  void _makeExplorationMove(NormalMove move) {
    if (_explorationPosition == null) return;

    try {
      // Convert chessground NormalMove to dartchess NormalMove
      final dcMove = NormalMove(from: move.from, to: move.to, promotion: move.promotion);
      final newPosition = _explorationPosition!.play(dcMove) as Chess;
      setState(() {
        _explorationPosition = newPosition;
      });
    } catch (e) {
      // Invalid move, ignore
    }
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
    final markerSize = squareSize * 0.4;
    final uci = move.uci;
    if (uci.length < 4) return const SizedBox.shrink();

    try {
      final toSquare = Square.fromName(uci.substring(2, 4));
      final file = toSquare.file;
      final rank = toSquare.rank;

      // Calculate position based on orientation
      double x;
      double y;

      if (_orientation == Side.black) {
        x = (7 - file).toDouble();
        y = rank.toDouble();
      } else {
        x = file.toDouble();
        y = (7 - rank).toDouble();
      }

      // Position marker in top-right corner of the square (Chess.com style)
      final left = x * squareSize + squareSize - markerSize * 1.1;
      final top = y * squareSize + markerSize * 0.1;

      return Positioned(
        left: left,
        top: top,
        child: MoveMarker(
          classification: move.classification,
          size: markerSize,
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
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

    final moves = state.review!.moves;
    // Group moves into pairs (white + black per row)
    final moveRows = <List<AnalyzedMove>>[];
    for (var i = 0; i < moves.length; i += 2) {
      final pair = <AnalyzedMove>[moves[i]];
      if (i + 1 < moves.length) {
        pair.add(moves[i + 1]);
      }
      moveRows.add(pair);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: moveRows.length,
      itemBuilder: (context, rowIndex) {
        final pair = moveRows[rowIndex];
        final moveNumber = rowIndex + 1;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: rowIndex.isEven
                ? (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              // Move number
              SizedBox(
                width: 28,
                child: Text(
                  '$moveNumber.',
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // White move
              Expanded(
                child: _buildMoveCell(pair[0], rowIndex * 2, state.currentMoveIndex, isDark),
              ),
              const SizedBox(width: 4),
              // Black move
              Expanded(
                child: pair.length > 1
                    ? _buildMoveCell(pair[1], rowIndex * 2 + 1, state.currentMoveIndex, isDark)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMoveCell(AnalyzedMove move, int moveIndex, int currentMoveIndex, bool isDark) {
    final isSelected = moveIndex == currentMoveIndex - 1;

    return GestureDetector(
      onTap: () {
        ref.read(gameReviewProvider(_userId).notifier).goToMove(moveIndex + 1);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? move.classification.color.withValues(alpha: 0.25)
              : move.classification.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: isSelected
              ? Border.all(color: move.classification.color, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mini marker
            SizedBox(
              width: 16,
              height: 16,
              child: MoveMarker(
                classification: move.classification,
                size: 16,
              ),
            ),
            const SizedBox(width: 4),
            // Move SAN
            Expanded(
              child: Text(
                move.san,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationControls(GameReviewState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${state.currentMoveIndex}/${state.review?.moves.length ?? 0}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
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

  Widget _buildActionButtons(GameReviewState state, bool isDark) {
    if (state.review == null) return const SizedBox.shrink();

    // Count mistakes for training mode
    final playerMistakes = state.review!.moves
        .where((m) => m.color == widget.game.playerColor)
        .where((m) => m.classification.isPuzzleWorthy)
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Practice button
          Expanded(
            child: SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: playerMistakes > 0
                    ? () => _navigateToPracticeMistakes(state)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MoveClassification.mistake.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.fitness_center, size: 16),
                label: Text(
                  'Practice ($playerMistakes)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Play vs Engine button
          Expanded(
            child: SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToPlayVsStockfish(state),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.smart_toy, size: 16),
                label: const Text(
                  'Play Engine',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPracticeMistakes(GameReviewState state) {
    if (state.review == null) return;

    // Get all player mistakes
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

    // Navigate to practice screen with mistakes
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

  void _navigateToPlayVsStockfish(GameReviewState state) {
    // Get current position FEN
    final currentFen = _position.fen;

    // Navigate to play vs Stockfish screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayVsStockfishScreen(
          startFen: currentFen,
          playerColor: widget.game.playerColor == 'white' ? Side.white : Side.black,
        ),
      ),
    );
  }

  /// Handle debug menu actions
  Future<void> _handleDebugAction(String action, String userId) async {
    switch (action) {
      case 'clear_analysis':
        // Clear local analysis data and go back
        await LocalDatabase.deleteGameReviewByGameId(userId, widget.game.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Analysis data cleared')),
          );
          Navigator.pop(context);
        }
        break;
      case 're_analyze':
        // Clear local data and re-analyze
        await LocalDatabase.deleteGameReviewByGameId(userId, widget.game.id);
        if (mounted) {
          ref.read(gameReviewProvider(userId).notifier).analyzeGame(widget.game);
        }
        break;
    }
  }
}
