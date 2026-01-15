import 'package:chessground/chessground.dart';
import 'package:confetti/confetti.dart';
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
import '../../gamification/models/xp_models.dart';
import '../../gamification/providers/gamification_provider.dart';
import '../models/analyzed_move.dart';
import '../models/game_puzzle.dart';
import '../widgets/move_markers.dart';
import 'practice_mistakes/completion_dialog.dart';
import 'practice_mistakes/feedback_message.dart';
import 'practice_mistakes/hint_marker.dart';
import 'practice_mistakes/practice_progress_bar.dart';

enum PuzzlePracticeState {
  ready, // Waiting for player move
  correct, // Player made correct move
  wrong, // Player made wrong move
  opponentPlaying, // Opponent is playing their response
  completed, // Puzzle completed
}

class PracticePuzzlesScreen extends ConsumerStatefulWidget {
  final List<GamePuzzle> puzzles;
  final String gameId;

  const PracticePuzzlesScreen({
    super.key,
    required this.puzzles,
    required this.gameId,
  });

  @override
  ConsumerState<PracticePuzzlesScreen> createState() => _PracticePuzzlesScreenState();
}

class _PracticePuzzlesScreenState extends ConsumerState<PracticePuzzlesScreen> {
  int _currentPuzzleIndex = 0;
  int _currentMoveIndex = 0; // Index within the solution sequence
  Chess? _position;
  Side _orientation = Side.white;
  PuzzlePracticeState _state = PuzzlePracticeState.ready;
  String? _feedback;
  int _correctPuzzles = 0;
  NormalMove? _lastMove;
  bool _showHint = false;
  MoveClassification? _feedbackMarker;
  bool _puzzleFailed = false; // Track if current puzzle had any wrong moves
  late ConfettiController _confettiController;
  int _totalXpEarned = 0;
  int? _initialTotalXp;

  GamePuzzle get currentPuzzle => widget.puzzles[_currentPuzzleIndex];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _loadPuzzle();

    // Get initial XP for tracking level ups
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gamificationState = ref.read(gamificationProvider);
      _initialTotalXp = gamificationState.totalXp;
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _loadPuzzle() {
    final puzzle = currentPuzzle;
    _position = Chess.fromSetup(Setup.parseFen(puzzle.fen));
    _orientation = puzzle.playerColor == 'white' ? Side.white : Side.black;
    _currentMoveIndex = 0;
    _state = PuzzlePracticeState.ready;
    _feedback = null;
    _feedbackMarker = null;
    _lastMove = null;
    _showHint = false;
    _puzzleFailed = false;
    setState(() {});
  }

  /// Get the expected move at current index
  String? get _expectedMoveUci {
    if (_currentMoveIndex >= currentPuzzle.solutionUci.length) return null;
    return currentPuzzle.solutionUci[_currentMoveIndex];
  }

  /// Number of player moves required
  int get _playerMovesRequired => (currentPuzzle.solutionUci.length + 1) ~/ 2;

  /// Current player move number (1-based)
  int get _currentPlayerMoveNumber => (_currentMoveIndex ~/ 2) + 1;

  void _makeMove(NormalMove move) {
    if (_position == null || _state != PuzzlePracticeState.ready) return;

    final uciMove = '${move.from.name}${move.to.name}${move.promotion?.letter ?? ''}';
    final expectedMove = _expectedMoveUci;

    // Play move sound
    _playMoveSound(move, _position!);

    if (uciMove == expectedMove) {
      _handleCorrectMove(move);
    } else {
      _handleWrongMove(move);
    }
  }

  void _handleCorrectMove(NormalMove move) {
    _lastMove = move;
    _feedbackMarker = MoveClassification.best;
    _position = _position!.play(move) as Chess;
    _currentMoveIndex++;
    _showHint = false;

    // Check if puzzle is complete
    if (_currentMoveIndex >= currentPuzzle.solutionUci.length) {
      _state = PuzzlePracticeState.completed;
      if (!_puzzleFailed) {
        _correctPuzzles++;
        // Award XP for solving puzzle correctly
        _awardPuzzleXp();
      }
      _feedback = 'Excellent! Puzzle complete!';
      // Play confetti for completed puzzle
      _confettiController.play();
      setState(() {});
    } else if (_currentMoveIndex % 2 == 1) {
      // Opponent's turn - play their move automatically
      _state = PuzzlePracticeState.opponentPlaying;
      _feedback = 'Good move!';
      setState(() {});

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          _playOpponentMove();
        }
      });
    } else {
      // Player's turn again
      _state = PuzzlePracticeState.ready;
      _feedback = 'Good! Keep going...';
      setState(() {});
    }
  }

  void _playOpponentMove() {
    if (_position == null || _currentMoveIndex >= currentPuzzle.solutionUci.length) return;

    final opponentMoveUci = currentPuzzle.solutionUci[_currentMoveIndex];
    final opponentMove = _parseUciMove(opponentMoveUci);

    if (opponentMove != null && _position!.legalMoves.containsKey(opponentMove.from)) {
      _playMoveSound(opponentMove, _position!);
      _lastMove = opponentMove;
      _position = _position!.play(opponentMove) as Chess;
      _currentMoveIndex++;

      // Check if puzzle is complete after opponent's move
      if (_currentMoveIndex >= currentPuzzle.solutionUci.length) {
        _state = PuzzlePracticeState.completed;
        if (!_puzzleFailed) {
          _correctPuzzles++;
        }
        _feedback = 'Excellent! Puzzle complete!';
      } else {
        _state = PuzzlePracticeState.ready;
        _feedback = 'Your turn - find the next move!';
      }
      setState(() {});
    }
  }

  void _handleWrongMove(NormalMove move) {
    _puzzleFailed = true;
    _state = PuzzlePracticeState.wrong;
    _feedbackMarker = MoveClassification.blunder;
    _lastMove = move;
    _showHint = false;
    _position = _position!.play(move) as Chess;
    _feedback = 'Not quite right. Try again!';
    setState(() {});

    // Reset to current position after delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _state == PuzzlePracticeState.wrong) {
        // Go back to the position before the wrong move
        _rebuildPosition();
        setState(() {
          _lastMove = null;
          _state = PuzzlePracticeState.ready;
          _feedback = null;
          _feedbackMarker = null;
        });
      }
    });
  }

  /// Rebuild position from start applying all correct moves so far
  void _rebuildPosition() {
    _position = Chess.fromSetup(Setup.parseFen(currentPuzzle.fen));
    for (int i = 0; i < _currentMoveIndex; i++) {
      final moveUci = currentPuzzle.solutionUci[i];
      final move = _parseUciMove(moveUci);
      if (move != null) {
        _position = _position!.play(move) as Chess;
      }
    }
  }

  void _awardPuzzleXp() {
    // Award XP for solving puzzle correctly
    const xpPerPuzzle = XpEventType.puzzleSolve;
    _totalXpEarned += xpPerPuzzle.defaultXp;

    // Actually award XP through the provider
    ref.read(gamificationProvider.notifier).awardXp(
      XpEventType.puzzleSolve,
      relatedId: widget.gameId,
    );
  }

  void _nextPuzzle() {
    if (_currentPuzzleIndex < widget.puzzles.length - 1) {
      _currentPuzzleIndex++;
      _loadPuzzle();
    } else {
      showPracticeCompletionDialog(
        context: context,
        correctCount: _correctPuzzles,
        total: widget.puzzles.length,
        totalXpEarned: _totalXpEarned,
        previousTotalXp: _initialTotalXp,
        onTryAgain: () {
          Navigator.pop(context);
          setState(() {
            _currentPuzzleIndex = 0;
            _correctPuzzles = 0;
            _totalXpEarned = 0;
            _loadPuzzle();
          });
        },
        onDone: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      );
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
          case 'r':
            promotion = Role.rook;
          case 'b':
            promotion = Role.bishop;
          case 'n':
            promotion = Role.knight;
        }
      }
      return NormalMove(from: from, to: to, promotion: promotion);
    } catch (e) {
      return null;
    }
  }

  IMap<Square, ISet<Square>> _getValidMoves() {
    if (_position == null || _state != PuzzlePracticeState.ready) return IMap(const {});
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
        title: Text('Puzzle ${_currentPuzzleIndex + 1}/${widget.puzzles.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
            tooltip: 'Board settings',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                _buildPuzzleHeader(isDark),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Stack(
                    children: [
                      _buildChessboard(boardSize),
                      if (_feedbackMarker != null && _lastMove != null)
                        _buildFeedbackMarker(boardSize),
                      if (_showHint && _expectedMoveUci != null)
                        _buildHintMarker(boardSize),
                    ],
                  ),
                ),
                if (_state == PuzzlePracticeState.ready)
                  _buildHintButton(isDark),
                if (_feedback != null)
                  FeedbackMessage(
                    message: _feedback!,
                    state: _mapToPracticeState(),
                    isDark: isDark,
                  ),
                _buildInstructions(isDark),
                PracticeProgressBar(
                  currentIndex: _currentPuzzleIndex,
                  total: widget.puzzles.length,
                  correctCount: _correctPuzzles,
                  isDark: isDark,
                ),
                // Navigation buttons - always visible
                _buildNavigationButtons(isDark),
                if (_state == PuzzlePracticeState.completed)
                  _buildActionButtons(isDark),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
          // Confetti overlay for puzzle completion
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.yellow,
              ],
              numberOfParticles: 20,
              maxBlastForce: 15,
              minBlastForce: 5,
              emissionFrequency: 0.05,
              gravity: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  PracticeState _mapToPracticeState() {
    switch (_state) {
      case PuzzlePracticeState.ready:
        return PracticeState.ready;
      case PuzzlePracticeState.correct:
      case PuzzlePracticeState.opponentPlaying:
      case PuzzlePracticeState.completed:
        return PracticeState.correct;
      case PuzzlePracticeState.wrong:
        return PracticeState.wrong;
    }
  }

  Widget _buildPuzzleHeader(bool isDark) {
    final puzzle = currentPuzzle;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _getClassificationColor(puzzle.classification).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              puzzle.classification.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getClassificationColor(puzzle.classification),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Move $_currentPlayerMoveNumber of $_playerMovesRequired',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (puzzle.theme != null)
                  Text(
                    puzzle.theme!.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          // Move counter dots
          Row(
            children: List.generate(
              _playerMovesRequired,
              (index) => Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < _currentPlayerMoveNumber
                      ? (_puzzleFailed ? Colors.orange : Colors.green)
                      : (isDark ? Colors.grey[600] : Colors.grey[300]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getClassificationColor(MoveClassification classification) {
    switch (classification) {
      case MoveClassification.blunder:
        return Colors.red;
      case MoveClassification.mistake:
        return Colors.orange;
      case MoveClassification.inaccuracy:
        return Colors.amber;
      default:
        return Colors.blue;
    }
  }

  Widget _buildChessboard(double boardSize) {
    if (_position == null) return SizedBox(width: boardSize, height: boardSize);

    final boardSettings = ref.watch(boardSettingsProvider);
    final settings = BoardSettingsFactory.create(boardSettings: boardSettings);
    final isPlayable = _state == PuzzlePracticeState.ready;
    final fen = _position!.fen;

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
    final expectedMove = _expectedMoveUci;
    if (expectedMove == null || expectedMove.length < 4) return const SizedBox.shrink();

    try {
      final from = Square.fromName(expectedMove.substring(0, 2));
      return HintMarkerOverlay(
        hintSquare: from,
        orientation: _orientation,
        boardSize: boardSize,
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  void _previousPuzzle() {
    if (_currentPuzzleIndex > 0) {
      _currentPuzzleIndex--;
      _loadPuzzle();
    }
  }

  void _skipPuzzle() {
    if (_currentPuzzleIndex < widget.puzzles.length - 1) {
      _currentPuzzleIndex++;
      _loadPuzzle();
    }
  }

  Widget _buildInstructions(bool isDark) {
    String text;
    switch (_state) {
      case PuzzlePracticeState.ready:
        text = _currentMoveIndex == 0
            ? 'Find the best move'
            : 'Find the next best move';
      case PuzzlePracticeState.opponentPlaying:
        text = 'Opponent is responding...';
      case PuzzlePracticeState.correct:
        text = 'Good move!';
      case PuzzlePracticeState.wrong:
        text = 'Not quite right...';
      case PuzzlePracticeState.completed:
        text = 'Puzzle complete!';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.grey.shade700),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildNavigationButtons(bool isDark) {
    final hasPrevious = _currentPuzzleIndex > 0;
    final hasNext = _currentPuzzleIndex < widget.puzzles.length - 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Previous button
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: hasPrevious ? _previousPuzzle : null,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: hasPrevious
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_back,
                        size: 18,
                        color: hasPrevious
                            ? (isDark ? Colors.white70 : Colors.grey.shade700)
                            : (isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Previous',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: hasPrevious
                              ? (isDark ? Colors.white70 : Colors.grey.shade700)
                              : (isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Skip/Next button
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: hasNext ? _skipPuzzle : null,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: hasNext
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: hasNext
                              ? (isDark ? Colors.white70 : Colors.grey.shade700)
                              : (isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: hasNext
                            ? (isDark ? Colors.white70 : Colors.grey.shade700)
                            : (isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _loadPuzzle,
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
                        Icon(Icons.refresh, size: 20, color: isDark ? Colors.white70 : Colors.grey.shade700),
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
                          _currentPuzzleIndex < widget.puzzles.length - 1
                              ? Icons.arrow_forward
                              : Icons.check_circle_outline,
                          size: 20,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentPuzzleIndex < widget.puzzles.length - 1 ? 'Next' : 'Finish',
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
