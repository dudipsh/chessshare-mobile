import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';

import '../../../app/theme/colors.dart';
import '../../games/models/chess_game.dart';
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
              const PopupMenuItem(value: 'share', child: Text('Share PGN')),
              const PopupMenuItem(value: 'copy_fen', child: Text('Copy FEN')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Evaluation bar
          if (_engineEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  // Evaluation text
                  SizedBox(
                    width: 50,
                    child: Text(
                      engineState.evaluation?.displayString ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  // Bar
                  Expanded(
                    child: CompactEvaluationBar(height: 6),
                  ),
                  // Analyzing indicator
                  SizedBox(
                    width: 24,
                    child: engineState.isAnalyzing
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                ],
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

  void _handleMenuAction(String value) {
    switch (value) {
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
}
