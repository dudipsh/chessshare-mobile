import 'dart:async';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/global_stockfish_manager.dart';
import '../../analysis/services/stockfish_service.dart';
import 'play_vs_stockfish/action_buttons.dart';
import 'play_vs_stockfish/board_settings.dart';
import 'play_vs_stockfish/engine_settings_sheet.dart';
import 'play_vs_stockfish/game_end_dialog.dart';
import 'play_vs_stockfish/game_info.dart';
import 'play_vs_stockfish/initialization_views.dart';
import 'play_vs_stockfish/status_bar.dart';

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
  int _engineLevel = 10;
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
      _stockfish = await GlobalStockfishManager.instance.acquire(
        _ownerId,
        config: StockfishConfig(
          multiPv: 1,
          hashSizeMb: 32,
          threads: 2,
          maxDepth: _engineLevel.clamp(1, 20),
        ),
      );

      if (!mounted) return;

      setState(() => _isInitializing = false);

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

  void _makePlayerMove(NormalMove move) async {
    if (_gameResult != null || _isThinking) return;

    try {
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

      if (_checkGameEnd()) return;
      _makeEngineMove();
    } catch (e) {
      debugPrint('Error making player move: $e');
    }
  }

  Future<void> _makeEngineMove() async {
    if (_stockfish == null || _gameResult != null) return;

    setState(() => _isThinking = true);

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
      final moveTimeMs = 200 + (_engineLevel * 100);
      _stockfish!.startAnalysis(moveTimeMs: moveTimeMs);

      final engineMove = await completer.future.timeout(
        Duration(milliseconds: moveTimeMs + 1000),
        onTimeout: () => bestMove,
      );

      _stockfishSubscription?.cancel();

      if (engineMove != null && engineMove.length >= 4 && mounted) {
        final move = _parseUciMove(engineMove);
        setState(() {
          _position = _position.play(move) as Chess;
          _lastMove = move;
          _moveHistory.add(engineMove);
          _isThinking = false;
        });
        _checkGameEnd();
      } else {
        setState(() => _isThinking = false);
      }
    } catch (e) {
      debugPrint('Engine move error: $e');
      setState(() => _isThinking = false);
    }
  }

  NormalMove _parseUciMove(String uci) {
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
      setState(() => _gameResult = result);
      _showGameEnd(result);
      return true;
    }
    return false;
  }

  void _showGameEnd(String result) {
    showGameEndDialog(
      context: context,
      result: result,
      playerColor: widget.playerColor,
      moveCount: _moveHistory.length,
      onPlayAgain: () {
        Navigator.pop(context);
        _resetGame();
      },
      onDone: () {
        Navigator.pop(context);
        Navigator.pop(context);
      },
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

  void _resign() async {
    final confirmed = await showResignDialog(context);
    if (confirmed && mounted) {
      setState(() => _gameResult = 'You resigned');
      _showGameEnd('You resigned');
    }
  }

  void _undoMove() {
    if (_moveHistory.length < 2 || _isThinking || _gameResult != null) return;

    setState(() {
      _moveHistory.removeLast();
      _moveHistory.removeLast();

      _position = Chess.fromSetup(Setup.parseFen(widget.startFen));
      for (final moveUci in _moveHistory) {
        final move = _parseUciMove(moveUci);
        _position = _position.play(move) as Chess;
      }
      _lastMove = null;
    });
  }

  IMap<Square, ISet<Square>> _getValidMoves() {
    if (_gameResult != null || _isThinking) return IMap(const {});

    final isPlayerTurn = (_position.turn == Side.white) == (widget.playerColor == Side.white);
    if (!isPlayerTurn) return IMap(const {});

    final Map<Square, ISet<Square>> result = {};
    for (final entry in _position.legalMoves.entries) {
      result[entry.key] = ISet(entry.value.squares.toList());
    }
    return IMap(result);
  }

  void _onEngineSettings() async {
    final newLevel = await showEngineSettingsSheet(
      context: context,
      currentLevel: _engineLevel,
    );

    if (newLevel != null && newLevel != _engineLevel) {
      setState(() => _engineLevel = newLevel);
      if (_stockfish != null) {
        await _stockfish!.updateConfig(
          StockfishConfig(
            multiPv: 1,
            hashSizeMb: 32,
            threads: 2,
            maxDepth: newLevel.clamp(1, 20),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _stockfishSubscription?.cancel();
    GlobalStockfishManager.instance.release(_ownerId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth - 16;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Play vs Engine'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _onEngineSettings,
            tooltip: 'Engine Level',
          ),
        ],
      ),
      body: _buildBody(boardSize),
    );
  }

  Widget _buildBody(double boardSize) {
    if (_isInitializing) {
      return const EngineInitializingView();
    }

    if (_initError != null) {
      return EngineErrorView(error: _initError!, onRetry: _initStockfish);
    }

    return Column(
      children: [
        EngineStatusBar(
          isThinking: _isThinking,
          gameResult: _gameResult,
          engineLevel: _engineLevel,
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildChessboard(boardSize),
        ),
        GameInfo(
          moveCount: _moveHistory.length,
          turn: _position.turn,
          isCheck: _position.isCheck,
        ),
        const Spacer(),
        GameActionButtons(
          canUndo: _moveHistory.length >= 2 && !_isThinking && _gameResult == null,
          onUndo: _undoMove,
          onReset: _resetGame,
          onResign: _gameResult == null ? _resign : null,
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }

  Widget _buildChessboard(double boardSize) {
    final isPlayerTurn = (_position.turn == Side.white) == (widget.playerColor == Side.white);
    final isPlayable = isPlayerTurn && !_isThinking && _gameResult == null;

    if (isPlayable) {
      return Chessboard(
        size: boardSize,
        settings: buildChessboardSettings(),
        orientation: widget.playerColor,
        fen: _position.fen,
        lastMove: _lastMove,
        game: GameData(
          playerSide: widget.playerColor == Side.white ? PlayerSide.white : PlayerSide.black,
          sideToMove: _position.turn,
          validMoves: _getValidMoves(),
          promotionMove: null,
          onMove: (move, {isDrop}) => _makePlayerMove(move),
          onPromotionSelection: (role) {},
        ),
      );
    } else {
      return Chessboard.fixed(
        size: boardSize,
        settings: buildChessboardSettings(),
        orientation: widget.playerColor,
        fen: _position.fen,
        lastMove: _lastMove,
      );
    }
  }
}
