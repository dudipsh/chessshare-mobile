/// Native implementation of StockfishService using dart:ffi
/// Only available on iOS, Android, macOS, Windows, Linux

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stockfish/stockfish.dart' hide StockfishState;

import '../stockfish_types.dart';

class StockfishService {
  // Singleton instance
  static StockfishService? _instance;
  static int _refCount = 0;

  Stockfish? _stockfish;
  StockfishState _state = StockfishState.uninitialized;
  StockfishConfig _config;
  StreamSubscription<String>? _outputSubscription;
  Completer<void>? _readyCompleter;

  final _outputController = StreamController<String>.broadcast();
  final _stateController = StreamController<StockfishState>.broadcast();

  /// Current engine state
  StockfishState get state => _state;

  /// Stream of raw UCI output lines
  Stream<String> get outputStream => _outputController.stream;

  /// Stream of state changes
  Stream<StockfishState> get stateStream => _stateController.stream;

  /// Current configuration
  StockfishConfig get config => _config;

  StockfishService._internal({StockfishConfig? config})
      : _config = config ?? const StockfishConfig();

  factory StockfishService({StockfishConfig? config}) {
    _refCount++;
    if (_instance == null) {
      _instance = StockfishService._internal(config: config);
    } else if (config != null) {
      _instance!._config = config;
    }
    return _instance!;
  }

  /// Initialize the Stockfish engine
  Future<void> initialize() async {
    // Already initialized and ready - just return
    if (_state == StockfishState.ready || _state == StockfishState.analyzing) {
      return;
    }

    // Not in a state that allows initialization
    if (_state != StockfishState.uninitialized &&
        _state != StockfishState.disposed &&
        _state != StockfishState.error) {
      return;
    }

    _setState(StockfishState.initializing);

    try {
      _stockfish = Stockfish();

      // Wait for the Stockfish binary to be ready before sending commands
      await _waitForStockfishReady();

      // Set up single listener that handles all output
      _readyCompleter = Completer<void>();
      _outputSubscription = _stockfish!.stdout.listen(_handleStdout);

      // Send UCI command to start protocol
      _send('uci');

      // Wait for uciok response
      await _readyCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Stockfish failed to respond to UCI');
        },
      );

      // Apply configuration
      await _applyConfig();

      _setState(StockfishState.ready);
    } catch (e) {
      debugPrint('Stockfish initialization error: $e');
      _setState(StockfishState.error);
      await _cleanup();
      rethrow;
    }
  }

  /// Wait for the Stockfish binary to finish starting
  Future<void> _waitForStockfishReady() async {
    if (_stockfish == null) return;

    // Poll until the stockfish state is ready (not starting)
    const maxWait = Duration(seconds: 10);
    const pollInterval = Duration(milliseconds: 100);
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < maxWait) {
      final stateValue = _stockfish!.state.value;

      // StockfishState from the package: starting, ready, disposed
      if (stateValue.name == 'ready') {
        return;
      }
      if (stateValue.name == 'disposed' || stateValue.name == 'error') {
        throw StateError('Stockfish was disposed or errored during initialization');
      }

      await Future.delayed(pollInterval);
    }

    throw TimeoutException('Stockfish binary failed to start');
  }

  void _handleStdout(String line) {
    _outputController.add(line);

    // Handle initialization response
    if (_readyCompleter != null && !_readyCompleter!.isCompleted) {
      if (line.contains('uciok') || line.contains('readyok')) {
        _readyCompleter!.complete();
      }
    }
  }

  Future<void> _cleanup() async {
    await _outputSubscription?.cancel();
    _outputSubscription = null;
    // Only dispose if stockfish is in a valid state (not error)
    if (_stockfish != null) {
      try {
        final stateName = _stockfish!.state.value.name;
        if (stateName == 'ready' || stateName == 'starting') {
          _stockfish!.dispose();
        }
      } catch (e) {
        debugPrint('Stockfish: Error during cleanup: $e');
      }
    }
    _stockfish = null;
  }

  /// Update engine configuration
  Future<void> updateConfig(StockfishConfig config) async {
    _config = config;
    if (_state == StockfishState.ready || _state == StockfishState.analyzing) {
      await stop();
      await _applyConfig();
    }
  }

  /// Set position from FEN
  void setPosition(String fen, [List<String>? moves]) {
    if (_stockfish == null) return;

    if (moves != null && moves.isNotEmpty) {
      _send('position fen $fen moves ${moves.join(' ')}');
    } else {
      _send('position fen $fen');
    }
  }

  /// Start analyzing current position
  void startAnalysis({int? depth, int? moveTimeMs}) {
    if (_stockfish == null) return;

    _setState(StockfishState.analyzing);

    final searchDepth = depth ?? _config.maxDepth;

    if (moveTimeMs != null) {
      _send('go movetime $moveTimeMs');
    } else if (searchDepth > 0) {
      _send('go depth $searchDepth');
    } else {
      _send('go infinite');
    }
  }

  /// Stop current analysis
  Future<void> stop() async {
    if (_stockfish == null || _state != StockfishState.analyzing) return;

    _send('stop');
    _setState(StockfishState.ready);

    // Small delay to ensure engine processes stop command
    await Future.delayed(const Duration(milliseconds: 50));
  }

  /// Get best move for current position (blocks until complete)
  Future<void> searchBestMove({int? depth, int? moveTimeMs}) async {
    startAnalysis(depth: depth, moveTimeMs: moveTimeMs);
  }

  /// Evaluate a position and return the score in centipawns
  Future<Map<String, dynamic>?> evaluatePosition(String fen, {int depth = 12}) async {
    if (_stockfish == null || _state == StockfishState.disposed) return null;

    // Stop any current analysis
    if (_state == StockfishState.analyzing) {
      await stop();
    }

    final completer = Completer<Map<String, dynamic>?>();
    int? lastScore;
    String? bestMove;

    // Listen for output
    late StreamSubscription<String> subscription;
    subscription = outputStream.listen((line) {
      // Parse info lines for score
      if (line.startsWith('info ') && line.contains('score')) {
        final scoreMatch = RegExp(r'score cp (-?\d+)').firstMatch(line);
        final mateMatch = RegExp(r'score mate (-?\d+)').firstMatch(line);

        if (scoreMatch != null) {
          lastScore = int.parse(scoreMatch.group(1)!);
        } else if (mateMatch != null) {
          final mateIn = int.parse(mateMatch.group(1)!);
          // Convert mate to centipawns (large value)
          lastScore = mateIn > 0 ? 10000 - mateIn * 100 : -10000 - mateIn * 100;
        }
      }

      // Parse bestmove to complete
      if (line.startsWith('bestmove ')) {
        final moveMatch = RegExp(r'bestmove (\S+)').firstMatch(line);
        if (moveMatch != null) {
          bestMove = moveMatch.group(1);
        }

        subscription.cancel();
        if (!completer.isCompleted) {
          if (lastScore != null) {
            completer.complete({'score': lastScore, 'bestMove': bestMove});
          } else {
            completer.complete(null);
          }
        }
      }
    });

    // Start analysis
    setPosition(fen);
    startAnalysis(depth: depth);

    // Timeout after 10 seconds
    try {
      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          subscription.cancel();
          stop();
          return lastScore != null ? {'score': lastScore, 'bestMove': bestMove} : null;
        },
      );
    } catch (e) {
      subscription.cancel();
      return null;
    }
  }

  /// Request engine to output current best line
  void requestPv() {
    // UCI doesn't have a direct command for this,
    // engine automatically outputs info lines during search
  }

  /// Dispose the engine and release resources
  /// Uses reference counting - only actually disposes when all references are released
  Future<void> dispose() async {
    _refCount--;

    // Only actually dispose when no more references
    if (_refCount > 0) {
      debugPrint('Stockfish: Skipping dispose, refCount=$_refCount');
      return;
    }

    if (_state == StockfishState.disposed) return;

    debugPrint('Stockfish: Actually disposing, refCount=$_refCount');

    // Only send commands if engine is ready
    if (_stockfish != null && _stockfish!.state.value.name == 'ready') {
      try {
        await stop();
        _send('quit');
      } catch (e) {
        debugPrint('Stockfish: Error during dispose: $e');
      }
    }

    await _outputSubscription?.cancel();
    if (_stockfish != null) {
      try {
        final stateName = _stockfish!.state.value.name;
        if (stateName == 'ready' || stateName == 'starting') {
          _stockfish!.dispose();
        }
      } catch (e) {
        debugPrint('Stockfish: Error disposing: $e');
      }
    }
    _stockfish = null;

    if (!_outputController.isClosed) {
      await _outputController.close();
    }
    if (!_stateController.isClosed) {
      await _stateController.close();
    }

    _setState(StockfishState.disposed);
    _instance = null;
  }

  void _send(String command) {
    if (_stockfish == null) return;
    // Only send if stockfish is ready
    if (_stockfish!.state.value.name != 'ready') {
      return;
    }
    _stockfish!.stdin = command;
  }

  void _setState(StockfishState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  Future<void> _applyConfig() async {
    _send('setoption name MultiPV value ${_config.multiPv}');
    _send('setoption name Hash value ${_config.hashSizeMb}');
    _send('setoption name Threads value ${_config.threads}');

    // Wait for ready confirmation using the unified completer
    _readyCompleter = Completer<void>();
    _send('isready');

    await _readyCompleter!.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        // Config apply timeout - proceed anyway
      },
    );
  }
}
