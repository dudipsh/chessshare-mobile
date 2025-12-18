import 'dart:async';

import 'package:stockfish/stockfish.dart';

/// Configuration for Stockfish engine
class StockfishConfig {
  /// Number of principal variations to compute (1-5)
  final int multiPv;

  /// Hash table size in MB
  final int hashSizeMb;

  /// Number of threads to use
  final int threads;

  /// Maximum search depth (0 = unlimited)
  final int maxDepth;

  const StockfishConfig({
    this.multiPv = 3,
    this.hashSizeMb = 32,
    this.threads = 1,
    this.maxDepth = 22,
  });

  StockfishConfig copyWith({
    int? multiPv,
    int? hashSizeMb,
    int? threads,
    int? maxDepth,
  }) {
    return StockfishConfig(
      multiPv: multiPv ?? this.multiPv,
      hashSizeMb: hashSizeMb ?? this.hashSizeMb,
      threads: threads ?? this.threads,
      maxDepth: maxDepth ?? this.maxDepth,
    );
  }
}

/// State of the Stockfish engine
enum StockfishState {
  uninitialized,
  initializing,
  ready,
  analyzing,
  disposed,
}

/// Service for communicating with Stockfish engine via UCI protocol
class StockfishService {
  Stockfish? _stockfish;
  StockfishState _state = StockfishState.uninitialized;
  StockfishConfig _config;
  StreamSubscription<String>? _outputSubscription;

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

  StockfishService({StockfishConfig? config})
      : _config = config ?? const StockfishConfig();

  /// Initialize the Stockfish engine
  Future<void> initialize() async {
    if (_state != StockfishState.uninitialized &&
        _state != StockfishState.disposed) {
      return;
    }

    _setState(StockfishState.initializing);

    try {
      _stockfish = Stockfish();

      _outputSubscription = _stockfish!.stdout.listen((line) {
        _outputController.add(line);
      });

      // Wait for engine to be ready
      await _waitForReady();

      // Apply configuration
      await _applyConfig();

      _setState(StockfishState.ready);
    } catch (e) {
      _setState(StockfishState.uninitialized);
      rethrow;
    }
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

  /// Request engine to output current best line
  void requestPv() {
    // UCI doesn't have a direct command for this,
    // engine automatically outputs info lines during search
  }

  /// Dispose the engine and release resources
  Future<void> dispose() async {
    if (_state == StockfishState.disposed) return;

    await stop();

    _send('quit');

    await _outputSubscription?.cancel();
    _stockfish?.dispose();
    _stockfish = null;

    await _outputController.close();
    await _stateController.close();

    _setState(StockfishState.disposed);
  }

  void _send(String command) {
    _stockfish?.stdin = command;
  }

  void _setState(StockfishState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  Future<void> _waitForReady() async {
    final completer = Completer<void>();

    late StreamSubscription<String> sub;
    sub = _stockfish!.stdout.listen((line) {
      if (line.contains('uciok') || line.contains('readyok')) {
        sub.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    _send('uci');

    // Timeout after 5 seconds
    await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        sub.cancel();
        throw TimeoutException('Stockfish failed to initialize');
      },
    );
  }

  Future<void> _applyConfig() async {
    _send('setoption name MultiPV value ${_config.multiPv}');
    _send('setoption name Hash value ${_config.hashSizeMb}');
    _send('setoption name Threads value ${_config.threads}');
    _send('isready');

    // Wait for ready confirmation
    final completer = Completer<void>();

    late StreamSubscription<String> sub;
    sub = _stockfish!.stdout.listen((line) {
      if (line.contains('readyok')) {
        sub.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    await completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        sub.cancel();
      },
    );
  }
}
