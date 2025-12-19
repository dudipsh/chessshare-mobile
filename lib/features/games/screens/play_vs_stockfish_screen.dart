import 'dart:async';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../core/services/global_stockfish_manager.dart';
import '../../analysis/services/stockfish_service.dart';

/// Screen for playing against Stockfish from a specific position
class PlayVsStockfishScreen extends ConsumerStatefulWidget {
  final String startFen;
  final Side playerColor;

  const PlayVsStockfishScreen({
    super.key,
    required this.startFen,
    required this.playerColor,
  });

  @override
  ConsumerState<PlayVsStockfishScreen> createState() => _PlayVsStockfishScreenState();
}

class _PlayVsStockfishScreenState extends ConsumerState<PlayVsStockfishScreen> {
  static const _ownerId = 'PlayVsStockfishScreen';

  late Chess _position;
  StockfishService? _stockfish;
  bool _isThinking = false;
  bool _isInitializing = true;
  String? _gameResult;
  String? _initError;
  List<String> _moveHistory = [];
  NormalMove? _lastMove;
  int _engineLevel = 10; // 1-20 scale
  StreamSubscription<String>? _stockfishSubscription;

  @override
  void initState() {
    super.initState();
    _position = Chess.fromSetup(Setup.parseFen(widget.startFen));
    _initStockfish();
  }

  Future<void> _initStockfish() async {
    setState(() {
      _isInitializing = true;
      _initError = null;
    });

    try {
      // Use global singleton manager
      _stockfish = await GlobalStockfishManager.instance.acquire(
        _ownerId,
        config: StockfishConfig(
          multiPv: 1,
          hashSizeMb: 32,
          threads: 2,
          maxDepth: _getDepthForLevel(_engineLevel),
        ),
      );

      if (!mounted) return;

      setState(() {
        _isInitializing = false;
      });

      // If it's engine's turn, make a move
      if (_shouldEngineMoveFirst()) {
        _makeEngineMove();
      }
    } catch (e) {
      debugPrint('PlayVsStockfish: Init error - $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initError = e.toString();
        });
      }
    }
  }

  bool _shouldEngineMoveFirst() {
    final isWhiteTurn = _position.turn == Side.white;
    final playerIsWhite = widget.playerColor == Side.white;
    return isWhiteTurn != playerIsWhite;
  }

  int _getDepthForLevel(int level) {
    // Map level 1-20 to depth 1-20
    return level.clamp(1, 20);
  }

  void _makePlayerMove(NormalMove move) async {
    if (_gameResult != null || _isThinking) return;

    // Validate and play the move
    try {
      // Check if the move is legal by verifying the target square is in valid moves
      final validMovesMap = _position.legalMoves;
      final fromSquare = move.from;
      final toSquare = move.to;

      if (!validMovesMap.containsKey(fromSquare)) return;
      final validTargets = validMovesMap[fromSquare];
      if (validTargets == null || !validTargets.squares.contains(toSquare)) return;

      setState(() {
        _position = _position.play(move) as Chess;
        _lastMove = move;
        _moveHistory.add('${move.from.name}${move.to.name}${move.promotion?.letter ?? ''}');
      });

      // Check for game end
      if (_checkGameEnd()) return;

      // Engine's turn
      _makeEngineMove();
    } catch (e) {
      debugPrint('Error making player move: $e');
    }
  }

  Future<void> _makeEngineMove() async {
    if (_stockfish == null || _gameResult != null) return;

    setState(() {
      _isThinking = true;
    });

    try {
      final completer = Completer<String?>();
      String? bestMove;

      _stockfishSubscription?.cancel();
      _stockfishSubscription = _stockfish!.outputStream.listen((line) {
        if (line.startsWith('bestmove')) {
          final parts = line.split(' ');
          if (parts.length >= 2 && parts[1] != '(none)') {
            bestMove = parts[1];
          }
          if (!completer.isCompleted) {
            completer.complete(bestMove);
          }
        }
      });

      _stockfish!.setPosition(_position.fen);

      // Use different time based on level for more natural play
      final moveTimeMs = 200 + (_engineLevel * 100); // 300ms to 2200ms
      _stockfish!.startAnalysis(moveTimeMs: moveTimeMs);

      final engineMove = await completer.future.timeout(
        Duration(milliseconds: moveTimeMs + 1000),
        onTimeout: () => bestMove,
      );

      _stockfishSubscription?.cancel();

      if (engineMove != null && engineMove.length >= 4 && mounted) {
        final from = Square.fromName(engineMove.substring(0, 2));
        final to = Square.fromName(engineMove.substring(2, 4));
        Role? promotion;
        if (engineMove.length > 4) {
          switch (engineMove[4].toLowerCase()) {
            case 'q': promotion = Role.queen; break;
            case 'r': promotion = Role.rook; break;
            case 'b': promotion = Role.bishop; break;
            case 'n': promotion = Role.knight; break;
          }
        }

        final move = NormalMove(from: from, to: to, promotion: promotion);
        setState(() {
          _position = _position.play(move) as Chess;
          _lastMove = move;
          _moveHistory.add(engineMove);
          _isThinking = false;
        });

        _checkGameEnd();
      } else {
        setState(() {
          _isThinking = false;
        });
      }
    } catch (e) {
      debugPrint('Engine move error: $e');
      setState(() {
        _isThinking = false;
      });
    }
  }

  bool _checkGameEnd() {
    String? result;

    if (_position.isCheckmate) {
      final winner = _position.turn == Side.white ? 'Black' : 'White';
      result = '$winner wins by checkmate!';
    } else if (_position.isStalemate) {
      result = 'Stalemate - Draw';
    } else if (_position.isInsufficientMaterial) {
      result = 'Insufficient material - Draw';
    } else if (_position.halfmoves >= 100) {
      result = 'Fifty-move rule - Draw';
    }

    if (result != null) {
      setState(() {
        _gameResult = result;
      });
      _showGameEndDialog(result);
      return true;
    }
    return false;
  }

  void _showGameEndDialog(String result) {
    final playerWon = (result.contains('White wins') && widget.playerColor == Side.white) ||
        (result.contains('Black wins') && widget.playerColor == Side.black);
    final playerLost = (result.contains('White wins') && widget.playerColor == Side.black) ||
        (result.contains('Black wins') && widget.playerColor == Side.white);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          playerWon ? 'You Win!' : playerLost ? 'You Lost' : 'Draw',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              playerWon
                  ? Icons.emoji_events
                  : playerLost
                      ? Icons.sentiment_dissatisfied
                      : Icons.handshake,
              size: 64,
              color: playerWon
                  ? Colors.amber
                  : playerLost
                      ? Colors.red
                      : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              result,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              '${_moveHistory.length} moves played',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetGame();
            },
            child: const Text('Play Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _resetGame() {
    setState(() {
      _position = Chess.fromSetup(Setup.parseFen(widget.startFen));
      _gameResult = null;
      _moveHistory = [];
      _lastMove = null;
      _isThinking = false;
    });

    if (_shouldEngineMoveFirst()) {
      _makeEngineMove();
    }
  }

  void _resign() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resign?'),
        content: const Text('Are you sure you want to resign?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _gameResult = 'You resigned';
              });
              _showGameEndDialog('You resigned');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Resign'),
          ),
        ],
      ),
    );
  }

  void _undoMove() {
    if (_moveHistory.length < 2 || _isThinking || _gameResult != null) return;

    // Undo last two moves (player's move and engine's response)
    setState(() {
      _moveHistory.removeLast();
      _moveHistory.removeLast();

      // Rebuild position from start
      _position = Chess.fromSetup(Setup.parseFen(widget.startFen));
      for (final moveUci in _moveHistory) {
        final from = Square.fromName(moveUci.substring(0, 2));
        final to = Square.fromName(moveUci.substring(2, 4));
        Role? promotion;
        if (moveUci.length > 4) {
          switch (moveUci[4].toLowerCase()) {
            case 'q': promotion = Role.queen; break;
            case 'r': promotion = Role.rook; break;
            case 'b': promotion = Role.bishop; break;
            case 'n': promotion = Role.knight; break;
          }
        }
        final move = NormalMove(from: from, to: to, promotion: promotion);
        _position = _position.play(move) as Chess;
      }

      _lastMove = null;
    });
  }

  IMap<Square, ISet<Square>> _getValidMoves() {
    if (_gameResult != null || _isThinking) {
      return IMap(const {});
    }

    // Only allow moves when it's the player's turn
    final isPlayerTurn = (_position.turn == Side.white) == (widget.playerColor == Side.white);
    if (!isPlayerTurn) {
      return IMap(const {});
    }

    return _convertToValidMoves(_position.legalMoves);
  }

  /// Convert dartchess SquareSet to chessground ISet<Square>
  IMap<Square, ISet<Square>> _convertToValidMoves(IMap<Square, SquareSet> dartchessMoves) {
    final Map<Square, ISet<Square>> result = {};
    for (final entry in dartchessMoves.entries) {
      final squares = <Square>[];
      for (final sq in entry.value.squares) {
        squares.add(sq);
      }
      result[entry.key] = ISet(squares);
    }
    return IMap(result);
  }

  @override
  void dispose() {
    _stockfishSubscription?.cancel();
    // Release from global manager instead of disposing directly
    GlobalStockfishManager.instance.release(_ownerId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth - 16;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Play vs Engine'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showEngineSettings,
            tooltip: 'Engine Level',
          ),
        ],
      ),
      body: _buildBody(isDark, boardSize),
    );
  }

  Widget _buildBody(bool isDark, double boardSize) {
    // Show initialization state
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Starting engine...'),
          ],
        ),
      );
    }

    // Show error state
    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to start engine',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _initError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initStockfish,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Engine status bar
        _buildStatusBar(isDark),

        // Chess board
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildChessboard(boardSize),
        ),

        // Game info
        _buildGameInfo(isDark),

        const Spacer(),

        // Action buttons
        _buildActionButtons(),

        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }

  Widget _buildStatusBar(bool isDark) {
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
          // Engine icon
          Icon(
            Icons.smart_toy,
            color: _isThinking ? AppColors.primary : Colors.grey,
          ),
          const SizedBox(width: 8),
          // Engine status
          Expanded(
            child: Text(
              _isThinking
                  ? 'Stockfish is thinking...'
                  : _gameResult != null
                      ? _gameResult!
                      : 'Level $_engineLevel',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: _isThinking ? AppColors.primary : null,
              ),
            ),
          ),
          // Thinking indicator
          if (_isThinking)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildChessboard(double boardSize) {
    final isPlayerTurn = (_position.turn == Side.white) == (widget.playerColor == Side.white);
    final isPlayable = isPlayerTurn && !_isThinking && _gameResult == null;

    if (isPlayable) {
      return Chessboard(
        size: boardSize,
        settings: _buildBoardSettings(),
        orientation: widget.playerColor,
        fen: _position.fen,
        lastMove: _lastMove,
        game: GameData(
          playerSide: widget.playerColor == Side.white ? PlayerSide.white : PlayerSide.black,
          sideToMove: _position.turn,
          validMoves: _getValidMoves(),
          promotionMove: null,
          onMove: (move, {isDrop}) {
            _makePlayerMove(move);
          },
          onPromotionSelection: (role) {},
        ),
      );
    } else {
      return Chessboard.fixed(
        size: boardSize,
        settings: _buildBoardSettings(),
        orientation: widget.playerColor,
        fen: _position.fen,
        lastMove: _lastMove,
      );
    }
  }

  Widget _buildGameInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem('Moves', '${_moveHistory.length}'),
          _buildInfoItem(
            'Turn',
            _position.turn == Side.white ? 'White' : 'Black',
          ),
          _buildInfoItem(
            'Check',
            _position.isCheck ? 'Yes' : 'No',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Undo button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _moveHistory.length >= 2 && !_isThinking && _gameResult == null
                  ? _undoMove
                  : null,
              icon: const Icon(Icons.undo),
              label: const Text('Undo'),
            ),
          ),
          const SizedBox(width: 8),
          // Reset button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _resetGame,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
            ),
          ),
          const SizedBox(width: 8),
          // Resign button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _gameResult == null ? _resign : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.flag),
              label: const Text('Resign'),
            ),
          ),
        ],
      ),
    );
  }

  void _showEngineSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Engine Level',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Level $_engineLevel',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Slider(
              value: _engineLevel.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              label: 'Level $_engineLevel',
              onChanged: (value) {
                setState(() {
                  _engineLevel = value.round();
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Beginner', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                Text('Master', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  // Update engine configuration
                  if (_stockfish != null) {
                    await _stockfish!.updateConfig(
                      StockfishConfig(
                        multiPv: 1,
                        hashSizeMb: 32,
                        threads: 2,
                        maxDepth: _getDepthForLevel(_engineLevel),
                      ),
                    );
                  }
                },
                child: const Text('Apply'),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
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
}
