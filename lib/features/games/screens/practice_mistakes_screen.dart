import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../core/providers/board_settings_provider.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/widgets/board_settings_sheet.dart';
import '../models/analyzed_move.dart';
import '../models/chess_game.dart';
import '../widgets/move_markers.dart';
import 'practice_mistakes/attempt_indicators.dart';
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
  int _wrongAttempts = 0;
  static const int _maxWrongAttempts = 3;
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
    _wrongAttempts = 0;
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
      _position = _position!.play(move) as Chess;
      setState(() {});
    } else {
      _wrongAttempts++;
      _state = PracticeState.wrong;
      _feedbackMarker = MoveClassification.blunder;
      _lastMove = move;
      _position = _position!.play(move) as Chess;
      setState(() {});

      if (_wrongAttempts >= _maxWrongAttempts) {
        _feedback = 'The best move was ${currentMistake.bestMove}';
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _showCorrectMove();
        });
      } else {
        _feedback = 'Try again (${_maxWrongAttempts - _wrongAttempts} attempts left)';
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
  }

  void _showCorrectMove() {
    final bestMoveUci = currentMistake.bestMoveUci;
    if (bestMoveUci != null && bestMoveUci.length >= 4) {
      try {
        _position = Chess.fromSetup(Setup.parseFen(currentMistake.fen));
        final from = Square.fromName(bestMoveUci.substring(0, 2));
        final to = Square.fromName(bestMoveUci.substring(2, 4));
        Role? promotion;
        if (bestMoveUci.length > 4) {
          switch (bestMoveUci[4].toLowerCase()) {
            case 'q': promotion = Role.queen; break;
            case 'r': promotion = Role.rook; break;
            case 'b': promotion = Role.bishop; break;
            case 'n': promotion = Role.knight; break;
          }
        }
        final move = NormalMove(from: from, to: to, promotion: promotion);
        _lastMove = move;
        _position = _position!.play(move) as Chess;
        _state = PracticeState.showingSolution;
        _feedbackMarker = MoveClassification.best;
        setState(() {});
      } catch (e) {
        debugPrint('Error showing correct move: $e');
      }
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
            AttemptIndicators(wrongAttempts: _wrongAttempts, maxAttempts: _maxWrongAttempts),
            if (_state == PracticeState.ready)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _showHint = !_showHint),
                  icon: Icon(
                    _showHint ? Icons.lightbulb : Icons.lightbulb_outline,
                    color: _showHint ? Colors.amber : null,
                  ),
                  label: Text(_showHint ? 'Hide Hint' : 'Show Hint'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                ),
              ),
            if (_feedback != null) FeedbackMessage(message: _feedback!, state: _state),
            Padding(
              padding: const EdgeInsets.all(16),
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
            ),
            if (_state == PracticeState.correct || _state == PracticeState.showingSolution)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: _loadPosition, child: const Text('Retry'))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _nextPuzzle,
                        child: Text(_currentIndex < widget.mistakes.length - 1 ? 'Next' : 'Finish'),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildChessboard(double boardSize) {
    if (_position == null) return SizedBox(width: boardSize, height: boardSize);

    final isPlayable = _state == PracticeState.ready;

    if (isPlayable) {
      return Chessboard(
        size: boardSize,
        settings: _buildBoardSettings(),
        orientation: _orientation,
        fen: _position!.fen,
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
      return Chessboard.fixed(
        size: boardSize,
        settings: _buildBoardSettings(),
        orientation: _orientation,
        fen: _position!.fen,
        lastMove: _lastMove,
      );
    }
  }

  Widget _buildFeedbackMarker(double boardSize) {
    if (_lastMove == null || _feedbackMarker == null) return const SizedBox.shrink();

    final squareSize = boardSize / 8;
    final markerSize = squareSize * 0.45;
    final toSquare = _lastMove!.to;

    double x = _orientation == Side.black ? (7 - toSquare.file).toDouble() : toSquare.file.toDouble();
    double y = _orientation == Side.black ? toSquare.rank.toDouble() : (7 - toSquare.rank).toDouble();

    final left = x * squareSize + squareSize - markerSize * 1.1;
    final top = y * squareSize + markerSize * 0.1;

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

  ChessboardSettings _buildBoardSettings() {
    final boardSettings = ref.watch(boardSettingsProvider);
    final lightSquare = boardSettings.colorScheme.lightSquare;
    final darkSquare = boardSettings.colorScheme.darkSquare;
    final pieceAssets = boardSettings.pieceSet.pieceSet.assets;

    return ChessboardSettings(
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
      showLastMove: true,
      animationDuration: const Duration(milliseconds: 150),
      dragFeedbackScale: 2.0,
      dragFeedbackOffset: const Offset(0, -1),
    );
  }

  String _getInstructions() {
    switch (_state) {
      case PracticeState.ready: return 'Find the best move';
      case PracticeState.correct: return 'Well done!';
      case PracticeState.wrong: return 'Not quite right...';
      case PracticeState.showingSolution: return 'This was the best move';
    }
  }
}
