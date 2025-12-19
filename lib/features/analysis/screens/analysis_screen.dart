import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../../games/models/chess_game.dart';
import '../../puzzles/providers/puzzle_generator_provider.dart';
import '../providers/analysis_provider.dart';
import '../providers/engine_provider.dart';
import '../widgets/analysis_panel.dart';
import '../widgets/evaluation_bar.dart';
import '../widgets/move_strip.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  final ChessGame game;

  const AnalysisScreen({super.key, required this.game});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  bool _engineEnabled = true;
  String? _lastAnalyzedFen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analysisProvider.notifier).loadGame(widget.game);
      _initializeEngine();
    });
  }

  Future<void> _initializeEngine() async {
    if (!_engineEnabled) return;
    await ref.read(engineAnalysisProvider.notifier).initialize();
  }

  void _analyzeCurrentPosition(String fen) {
    if (!_engineEnabled || fen == _lastAnalyzedFen) return;
    _lastAnalyzedFen = fen;
    ref.read(engineAnalysisProvider.notifier).analyzePosition(fen);
  }

  @override
  void dispose() {
    ref.read(engineAnalysisProvider.notifier).stopAnalysis();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analysisState = ref.watch(analysisProvider);
    final engineState = ref.watch(engineAnalysisProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Trigger analysis when FEN changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analyzeCurrentPosition(analysisState.currentFen);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'vs ${widget.game.opponentUsername}',
          style: const TextStyle(fontSize: 17),
        ),
        actions: [
          // Engine toggle
          IconButton(
            icon: Icon(
              _engineEnabled ? Icons.psychology : Icons.psychology_outlined,
              color: _engineEnabled ? AppColors.primary : null,
            ),
            onPressed: () {
              setState(() {
                _engineEnabled = !_engineEnabled;
              });
              if (_engineEnabled) {
                _initializeEngine();
                _lastAnalyzedFen = null;
              } else {
                ref.read(engineAnalysisProvider.notifier).stopAnalysis();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.swap_vert),
            onPressed: () {
              ref.read(analysisProvider.notifier).flipBoard();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'generate_puzzles',
                child: Text('Generate Puzzles'),
              ),
              const PopupMenuItem(value: 'share', child: Text('Share PGN')),
              const PopupMenuItem(value: 'copy_fen', child: Text('Copy FEN')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Evaluation bar (same width as board)
          if (_engineEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: SizedBox(
                width: screenWidth - 16,
                child: _buildEvaluationSection(engineState, isDark, screenWidth - 16),
              ),
            ),

          // Chess board - always interactive
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildChessboard(analysisState, screenWidth - 16),
          ),

          // Move strip with swipe
          CompactMoveNavigator(
            moves: analysisState.sanMoves,
            currentIndex: analysisState.currentMoveIndex,
            onMoveSelected: (index) {
              ref.read(analysisProvider.notifier).goToMove(index);
            },
          ),

          const SizedBox(height: 8),

          // Engine analysis panel
          if (_engineEnabled)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: AnalysisPanel(
                  maxLines: 3,
                  onPvTap: (pv) {
                    // Preview PV on board
                  },
                ),
              ),
            ),

          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildChessboard(AnalysisState analysisState, double boardSize) {
    final notifier = ref.read(analysisProvider.notifier);

    // Board is always interactive - user can move pieces
    return Chessboard(
      size: boardSize,
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
        onPromotionSelection: (role) {},
      ),
    );
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
  }

  Widget _buildEvaluationSection(EngineAnalysisState engineState, bool isDark, double width) {
    // Determine status message
    String? statusMessage;
    if (engineState.error != null) {
      statusMessage = 'Engine error: ${engineState.error}';
    } else if (!engineState.isReady) {
      statusMessage = 'Starting engine...';
    } else if (engineState.isAnalyzing && engineState.evaluation == null) {
      statusMessage = 'Analyzing...';
    } else if (engineState.evaluation == null && engineState.bestMove == null) {
      statusMessage = 'No analysis yet';
    }

    if (statusMessage != null) {
      return Container(
        width: width,
        height: 28,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            statusMessage,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
      );
    }

    // Show actual evaluation bar
    return const EvaluationBar();
  }

  void _handleMenuAction(String value) {
    switch (value) {
      case 'generate_puzzles':
        _generatePuzzles();
        break;
      case 'share':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Share coming soon')),
        );
        break;
      case 'copy_fen':
        final fen = ref.read(analysisProvider).currentFen;
        Clipboard.setData(ClipboardData(text: fen));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('FEN copied')),
        );
        break;
    }
  }

  Future<void> _generatePuzzles() async {
    final pgn = widget.game.pgn;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating puzzles from your game...'),
        duration: Duration(seconds: 2),
      ),
    );

    // Generate puzzles
    await ref.read(puzzleGeneratorProvider.notifier).generateFromPgn(pgn);

    // Check result
    final state = ref.read(puzzleGeneratorProvider);
    if (mounted) {
      if (state.puzzles.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${state.puzzles.length} puzzles!'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () => context.goNamed('puzzles'),
            ),
          ),
        );
      } else if (state.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error!),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tactical puzzles found in this game'),
          ),
        );
      }
    }
  }
}
