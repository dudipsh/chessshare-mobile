import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/board_settings_provider.dart';
import '../../../core/providers/captured_pieces_provider.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/widgets/board_settings_factory.dart';
import '../../../core/widgets/board_settings_sheet.dart';
import '../../../core/widgets/chess_board_shell.dart';
import '../models/analyzed_move.dart';
import '../models/chess_game.dart';
import '../widgets/move_markers.dart';
import 'practice_mistakes/completion_dialog.dart';
import 'practice_mistakes/feedback_message.dart';
import 'practice_mistakes/hint_marker.dart';
import 'practice_mistakes/mistake_info_header.dart';
import 'practice_mistakes/practice_progress_bar.dart';

class PracticeMistakesScreen extends ConsumerStatefulWidget {
  final List<AnalyzedMove> mistakes;
  final ChessGame game;
  final String reviewId;

  const PracticeMistakesScreen({
    super.key,
    required this.mistakes,
    required this.game,
    required this.reviewId,
  });

  @override
  ConsumerState<PracticeMistakesScreen> createState() => _PracticeMistakesScreenState();
}

class _PracticeMistakesScreenState extends ConsumerState<PracticeMistakesScreen> {
  int _currentIndex = 0;
  Chess? _position;
  Side _orientation = Side.white;
  PracticeState _state = PracticeState.ready;
  String? _feedback;
  int _correctCount = 0;
  NormalMove? _lastMove;
  bool _showHint = false;
  MoveClassification? _feedbackMarker;

  AnalyzedMove get currentMistake => widget.mistakes[_currentIndex];

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  void _loadPosition() {
    final mistake = currentMistake;
    _position = Chess.fromSetup(Setup.parseFen(mistake.fen));
    _orientation = mistake.color == 'white' ? Side.white : Side.black;
    _state = PracticeState.ready;
    _feedback = null;
    _feedbackMarker = null;
    _lastMove = null;
    _showHint = false;
    setState(() {});
  }

  void _makeMove(NormalMove move) {
    if (_position == null || _state != PracticeState.ready) return;

    final uciMove = '${move.from.name}${move.to.name}${move.promotion?.letter ?? ''}';
    final bestMoveUci = currentMistake.bestMoveUci;

    // Play move sound
    _playMoveSound(move, _position!);

    if (uciMove == bestMoveUci) {
      _correctCount++;
      _state = PracticeState.correct;
      _feedback = 'Correct! That was the best move.';
      _feedbackMarker = MoveClassification.best;
      _lastMove = move;
      _showHint = false; // Hide hint after making move
      _position = _position!.play(move) as Chess;
      setState(() {});
    } else {
      _state = PracticeState.wrong;
      _feedbackMarker = MoveClassification.blunder;
      _lastMove = move;
      _showHint = false; // Hide hint after making move
      _position = _position!.play(move) as Chess;
      setState(() {});

      // No limit on attempts - always allow retry
      _feedback = 'Try again';
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _state == PracticeState.wrong) {
          setState(() {
            _position = Chess.fromSetup(Setup.parseFen(currentMistake.fen));
            _lastMove = null;
            _state = PracticeState.ready;
            _feedback = null;
            _feedbackMarker = null;
          });
        }
      });
    }
  }

  void _nextPuzzle() {
    if (_currentIndex < widget.mistakes.length - 1) {
      _currentIndex++;
      _loadPosition();
    } else {
      showPracticeCompletionDialog(
        context: context,
        correctCount: _correctCount,
        total: widget.mistakes.length,
        onTryAgain: () {
          Navigator.pop(context);
          setState(() {
            _currentIndex = 0;
            _correctCount = 0;
            _loadPosition();
          });
        },
        onDone: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      );
    }
  }

  IMap<Square, ISet<Square>> _getValidMoves() {
    if (_position == null || _state != PracticeState.ready) return IMap(const {});
    final Map<Square, ISet<Square>> result = {};
    for (final entry in _position!.legalMoves.entries) {
      result[entry.key] = ISet(entry.value.squares.toList());
    }
    return IMap(result);
  }

  void _showSettings() {
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

  void _playMoveSound(NormalMove move, Chess positionBefore) {
    final audioService = ref.read(audioServiceProvider);
    final san = positionBefore.makeSan(move).$2;
    final isCapture = san.contains('x');
    final isCheck = san.contains('+') || san.contains('#');
    final isCastle = san == 'O-O' || san == 'O-O-O';

    Chess? positionAfter;
    try {
      positionAfter = positionBefore.play(move) as Chess;
    } catch (_) {}

    audioService.playMoveWithHaptic(
      isCapture: isCapture,
      isCheck: isCheck,
      isCastle: isCastle,
      isCheckmate: positionAfter?.isCheckmate ?? false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth - 16;

    return Scaffold(
      appBar: AppBar(
        title: Text('Practice (${_currentIndex + 1}/${widget.mistakes.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
            tooltip: 'Board settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            MistakeInfoHeader(mistake: currentMistake, isDark: isDark),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Stack(
                children: [
                  _buildChessboard(boardSize),
                  if (_feedbackMarker != null && _lastMove != null)
                    _buildFeedbackMarker(boardSize),
                  if (_showHint && currentMistake.bestMoveUci != null)
                    _buildHintMarker(boardSize),
                ],
              ),
            ),
            // Hint button with card style
            if (_state == PracticeState.ready)
              _buildHintButton(isDark),
            if (_feedback != null) FeedbackMessage(message: _feedback!, state: _state, isDark: isDark),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                _getInstructions(),
                style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
            ),
            PracticeProgressBar(
              currentIndex: _currentIndex,
              total: widget.mistakes.length,
              correctCount: _correctCount,
              isDark: isDark,
            ),
            if (_state == PracticeState.correct || _state == PracticeState.showingSolution)
              _buildActionButtons(isDark),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildChessboard(double boardSize) {
    if (_position == null) return SizedBox(width: boardSize, height: boardSize);

    final boardSettings = ref.watch(boardSettingsProvider);
    final settings = BoardSettingsFactory.create(boardSettings: boardSettings);
    final isPlayable = _state == PracticeState.ready;
    final fen = _position!.fen;

    // Update captured pieces
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(capturedPiecesProvider.notifier).updateFromFen(fen);
    });

    Widget chessBoard;
    if (isPlayable) {
      chessBoard = Chessboard(
        size: boardSize,
        settings: settings,
        orientation: _orientation,
        fen: fen,
        lastMove: _lastMove,
        game: GameData(
          playerSide: _orientation == Side.white ? PlayerSide.white : PlayerSide.black,
          sideToMove: _position!.turn,
          validMoves: _getValidMoves(),
          promotionMove: null,
          onMove: (move, {isDrop}) => _makeMove(move),
          onPromotionSelection: (role) {},
        ),
      );
    } else {
      chessBoard = Chessboard.fixed(
        size: boardSize,
        settings: settings,
        orientation: _orientation,
        fen: fen,
        lastMove: _lastMove,
      );
    }

    return ChessBoardShell(
      board: chessBoard,
      orientation: _orientation,
      fen: fen,
      showCapturedPieces: true,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildFeedbackMarker(double boardSize) {
    if (_lastMove == null || _feedbackMarker == null) return const SizedBox.shrink();

    final squareSize = boardSize / 8;
    final markerSize = squareSize * 0.45;
    final toSquare = _lastMove!.to;

    // Account for the captured pieces slot at the top (24px default height in ChessBoardShell)
    const capturedPiecesSlotHeight = 24.0;

    double x = _orientation == Side.black ? (7 - toSquare.file).toDouble() : toSquare.file.toDouble();
    double y = _orientation == Side.black ? toSquare.rank.toDouble() : (7 - toSquare.rank).toDouble();

    final left = x * squareSize + squareSize - markerSize * 1.1;
    final top = capturedPiecesSlotHeight + y * squareSize + markerSize * 0.1;

    return Positioned(
      left: left,
      top: top,
      child: MoveMarker(classification: _feedbackMarker!, size: markerSize),
    );
  }

  Widget _buildHintMarker(double boardSize) {
    final bestMoveUci = currentMistake.bestMoveUci;
    if (bestMoveUci == null || bestMoveUci.length < 4) return const SizedBox.shrink();

    try {
      final from = Square.fromName(bestMoveUci.substring(0, 2));

      return HintMarkerOverlay(
        hintSquare: from,
        orientation: _orientation,
        boardSize: boardSize,
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  String _getInstructions() {
    switch (_state) {
      case PracticeState.ready: return 'Find the best move';
      case PracticeState.correct: return 'Well done!';
      case PracticeState.wrong: return 'Not quite right...';
      case PracticeState.showingSolution: return 'This was the best move';
    }
  }

  Widget _buildHintButton(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _showHint = !_showHint),
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
                    Colors.amber.withValues(alpha: _showHint ? 0.25 : 0.12),
                    Colors.orange.withValues(alpha: _showHint ? 0.15 : 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showHint ? Icons.lightbulb : Icons.lightbulb_outline,
                    size: 20,
                    color: Colors.amber.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _showHint ? 'Hide Hint' : 'Show Hint',
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

  Widget _buildActionButtons(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Retry button
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _loadPosition,
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
                          Colors.grey.withValues(alpha: 0.12),
                          Colors.grey.withValues(alpha: 0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 20,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Next/Finish button
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _nextPuzzle,
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
                          Colors.green.withValues(alpha: 0.15),
                          Colors.teal.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _currentIndex < widget.mistakes.length - 1
                              ? Icons.arrow_forward
                              : Icons.check_circle_outline,
                          size: 20,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentIndex < widget.mistakes.length - 1 ? 'Next' : 'Finish',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
