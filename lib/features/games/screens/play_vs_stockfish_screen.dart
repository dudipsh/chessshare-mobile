import 'dart:async';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/board_settings_provider.dart';
import '../../../core/providers/captured_pieces_provider.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/global_stockfish_manager.dart';
import '../../../core/widgets/board_settings_factory.dart';
import '../../../core/widgets/chess_board_shell.dart';
import '../../analysis/services/stockfish_service.dart';
import 'play_vs_stockfish/action_buttons.dart';
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
  static const _ownerId = 'shared'; // Use shared owner to reuse pre-loaded instance

  late Chess _position;
  StockfishService? _stockfish;
  bool _isThinking = false;
  bool _isInitializing = true;
  String? _gameResult;
  String? _initError;
  List<String> _moveHistory = [];
  NormalMove? _lastMove;
  int _engineLevel = 10;
  int? _evalCp;
  StreamSubscription<String>? _stockfishSubscription;
  StreamSubscription<String>? _evalSubscription;

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
        config: StockfishConfig.forPlaying(level: _engineLevel),
      );

      if (!mounted) return;

      setState(() => _isInitializing = false);

      // Start listening for evaluations
      _evaluatePosition();

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

      // Play sound before updating position
      _playMoveSound(move, _position);

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
        // Play sound before updating position
        _playMoveSound(move, _position);
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

  void _playMoveSound(NormalMove move, Chess positionBefore) {
    try {
      final san = positionBefore.makeSan(move).$2;
      final isCapture = san.contains('x');
      final isCheck = san.contains('+') || san.contains('#');
      final isCastle = san == 'O-O' || san == 'O-O-O';

      Chess? positionAfter;
      try {
        positionAfter = positionBefore.play(move) as Chess;
      } catch (_) {}

      ref.read(audioServiceProvider).playMoveWithHaptic(
        isCapture: isCapture,
        isCheck: isCheck,
        isCastle: isCastle,
        isCheckmate: positionAfter?.isCheckmate ?? false,
      );
    } catch (_) {}
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
          StockfishConfig.forPlaying(level: newLevel),
        );
      }
    }
  }

  void _evaluatePosition() async {
    if (_stockfish == null || _gameResult != null) return;

    _evalSubscription?.cancel();
    int? lastScore;

    _evalSubscription = _stockfish!.outputStream.listen((line) {
      if (line.startsWith('info ') && line.contains('score')) {
        final scoreMatch = RegExp(r'score cp (-?\d+)').firstMatch(line);
        final mateMatch = RegExp(r'score mate (-?\d+)').firstMatch(line);

        if (scoreMatch != null) {
          lastScore = int.parse(scoreMatch.group(1)!);
        } else if (mateMatch != null) {
          final mateIn = int.parse(mateMatch.group(1)!);
          lastScore = mateIn > 0 ? 10000 - mateIn * 100 : -10000 - mateIn * 100;
        }

        if (lastScore != null && mounted) {
          setState(() => _evalCp = lastScore);
        }
      }
    });
  }

  @override
  void dispose() {
    _stockfishSubscription?.cancel();
    _evalSubscription?.cancel();
    GlobalStockfishManager.instance.release(_ownerId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth - 16;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _buildEvalBadge(_evalCp, isDark),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Play vs Engine',
                style: TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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

  Widget _buildEvalBadge(int? evalCp, bool isDark) {
    String text = '0.0';
    Color bgColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    Color textColor = isDark ? Colors.white : Colors.black87;

    if (evalCp != null) {
      if (evalCp.abs() >= 10000) {
        // Mate score
        final mateIn = ((10000 - evalCp.abs()) / 100).ceil();
        text = evalCp > 0 ? 'M$mateIn' : '-M$mateIn';
        bgColor = evalCp > 0 ? Colors.white : Colors.grey.shade800;
        textColor = evalCp > 0 ? Colors.black87 : Colors.white;
      } else {
        // Centipawn score
        final pawns = evalCp / 100;
        if (pawns > 0) {
          text = '+${pawns.toStringAsFixed(1)}';
          bgColor = Colors.white;
          textColor = Colors.black87;
        } else if (pawns < 0) {
          text = pawns.toStringAsFixed(1);
          bgColor = Colors.grey.shade800;
          textColor = Colors.white;
        }
      }
    }

    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          width: 1,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
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
    final boardSettings = ref.watch(boardSettingsProvider);
    final settings = BoardSettingsFactory.create(boardSettings: boardSettings);
    final isPlayerTurn = (_position.turn == Side.white) == (widget.playerColor == Side.white);
    final isPlayable = isPlayerTurn && !_isThinking && _gameResult == null;
    final fen = _position.fen;

    // Update captured pieces
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(capturedPiecesProvider.notifier).updateFromFen(fen);
    });

    Widget chessBoard;
    if (isPlayable) {
      chessBoard = Chessboard(
        size: boardSize,
        settings: settings,
        orientation: widget.playerColor,
        fen: fen,
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
      chessBoard = Chessboard.fixed(
        size: boardSize,
        settings: settings,
        orientation: widget.playerColor,
        fen: fen,
        lastMove: _lastMove,
      );
    }

    return ChessBoardShell(
      board: chessBoard,
      orientation: widget.playerColor,
      fen: fen,
      showCapturedPieces: true,
      padding: EdgeInsets.zero,
    );
  }
}
