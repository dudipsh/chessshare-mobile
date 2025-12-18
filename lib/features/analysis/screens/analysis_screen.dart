import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';

import '../../../app/theme/colors.dart';
import '../../games/models/chess_game.dart';
import '../providers/analysis_provider.dart';
import '../widgets/move_list.dart';
import '../widgets/navigation_controls.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  final ChessGame game;

  const AnalysisScreen({super.key, required this.game});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  @override
  void initState() {
    super.initState();
    // Load the game when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analysisProvider.notifier).loadGame(widget.game);
    });
  }

  @override
  Widget build(BuildContext context) {
    final analysisState = ref.watch(analysisProvider);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'vs ${widget.game.opponentUsername}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              widget.game.openingName ?? 'Game Analysis',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              analysisState.orientation == Side.black
                  ? Icons.swap_vert
                  : Icons.swap_vert_outlined,
            ),
            onPressed: () {
              ref.read(analysisProvider.notifier).flipBoard();
            },
            tooltip: 'Flip board',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'share':
                  _sharePgn();
                  break;
                case 'copy_fen':
                  _copyFen();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20),
                    SizedBox(width: 12),
                    Text('Share PGN'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy_fen',
                child: Row(
                  children: [
                    Icon(Icons.copy, size: 20),
                    SizedBox(width: 12),
                    Text('Copy FEN'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Game info bar
          _buildGameInfoBar(),

          // Chess board with chessground
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildChessboard(analysisState, screenWidth),
          ),

          // Navigation controls
          NavigationControls(
            onFirst: analysisState.canGoBack
                ? () => ref.read(analysisProvider.notifier).goToStart()
                : null,
            onPrevious: analysisState.canGoBack
                ? () => ref.read(analysisProvider.notifier).goBack()
                : null,
            onNext: analysisState.canGoForward
                ? () => ref.read(analysisProvider.notifier).goForward()
                : null,
            onLast: analysisState.canGoForward
                ? () => ref.read(analysisProvider.notifier).goToEnd()
                : null,
          ),

          // Current move display
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              analysisState.currentMoveDisplay,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Move list
          Expanded(
            child: MoveList(
              moves: analysisState.sanMoves,
              currentIndex: analysisState.currentMoveIndex,
              onMoveSelected: (index) {
                ref.read(analysisProvider.notifier).goToMove(index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChessboard(AnalysisState analysisState, double screenWidth) {
    final notifier = ref.read(analysisProvider.notifier);

    // Use fixed board when not at end (view-only), interactive when at end
    if (analysisState.isAtEnd) {
      return Chessboard(
        size: screenWidth - 16,
        settings: _buildBoardSettings(),
        orientation: analysisState.orientation,
        fen: analysisState.currentFen,
        lastMove: analysisState.lastMove,
        game: GameData(
          playerSide: PlayerSide.both,
          sideToMove: notifier.sideToMove,
          validMoves: analysisState.validMoves,
          promotionMove: null,
          onMove: (move, {isDrop}) {
            notifier.onUserMove(move, isDrop: isDrop);
          },
          onPromotionSelection: (role) {
            // Handle promotion - for now just auto-queen
          },
        ),
      );
    } else {
      return Chessboard.fixed(
        size: screenWidth - 16,
        settings: _buildBoardSettings(),
        orientation: analysisState.orientation,
        fen: analysisState.currentFen,
        lastMove: analysisState.lastMove,
      );
    }
  }

  ChessboardSettings _buildBoardSettings() {
    return ChessboardSettings(
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
        lastMove: HighlightDetails(
          solidColor: AppColors.lastMove,
        ),
        selected: HighlightDetails(
          solidColor: AppColors.highlight,
        ),
        validMoves: Colors.black.withValues(alpha: 0.15),
        validPremoves: Colors.blue.withValues(alpha: 0.2),
      ),
      showValidMoves: true,
      showLastMove: true,
      animationDuration: const Duration(milliseconds: 200),
      dragFeedbackScale: 2.0,
      dragFeedbackOffset: const Offset(0, -1),
    );
  }

  Widget _buildGameInfoBar() {
    final game = widget.game;
    final resultColor = _getResultColor(game.result);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          // Result badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              game.result.name.toUpperCase(),
              style: TextStyle(
                color: resultColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Ratings
          if (game.playerRating != null || game.opponentRating != null)
            Text(
              '${game.playerRating ?? '?'} vs ${game.opponentRating ?? '?'}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),

          const Spacer(),

          // Time control
          if (game.timeControl != null)
            Row(
              children: [
                Icon(
                  _getSpeedIcon(game.speed),
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  game.timeControl!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _getResultColor(GameResult result) {
    switch (result) {
      case GameResult.win:
        return AppColors.win;
      case GameResult.loss:
        return AppColors.loss;
      case GameResult.draw:
        return AppColors.draw;
    }
  }

  IconData _getSpeedIcon(GameSpeed speed) {
    switch (speed) {
      case GameSpeed.bullet:
        return Icons.bolt;
      case GameSpeed.blitz:
        return Icons.flash_on;
      case GameSpeed.rapid:
        return Icons.timer;
      case GameSpeed.classical:
        return Icons.hourglass_bottom;
      case GameSpeed.correspondence:
        return Icons.mail_outline;
    }
  }

  void _sharePgn() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share coming soon')),
    );
  }

  void _copyFen() {
    final fen = ref.read(analysisProvider).currentFen;
    Clipboard.setData(ClipboardData(text: fen));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('FEN copied to clipboard')),
    );
  }
}
