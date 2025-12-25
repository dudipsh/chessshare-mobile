/// Stub implementation of StockfishService for web platform
/// Stockfish uses dart:ffi which is not available on web

import 'dart:async';
import '../stockfish_types.dart';

class StockfishService {
  StockfishState _state = StockfishState.uninitialized;
  final StockfishConfig _config;

  final _outputController = StreamController<String>.broadcast();
  final _stateController = StreamController<StockfishState>.broadcast();

  StockfishState get state => _state;
  Stream<String> get outputStream => _outputController.stream;
  Stream<StockfishState> get stateStream => _stateController.stream;
  StockfishConfig get config => _config;

  StockfishService({StockfishConfig? config})
      : _config = config ?? const StockfishConfig();

  Future<void> initialize() async {
    throw UnsupportedError('Stockfish is not supported on web platform');
  }

  Future<void> updateConfig(StockfishConfig config) async {
    throw UnsupportedError('Stockfish is not supported on web platform');
  }

  void setPosition(String fen, [List<String>? moves]) {
    throw UnsupportedError('Stockfish is not supported on web platform');
  }

  void startAnalysis({int? depth, int? moveTimeMs}) {
    throw UnsupportedError('Stockfish is not supported on web platform');
  }

  Future<void> stop() async {}

  Future<void> searchBestMove({int? depth, int? moveTimeMs}) async {
    throw UnsupportedError('Stockfish is not supported on web platform');
  }

  Future<Map<String, dynamic>?> evaluatePosition(String fen, {int depth = 12}) async {
    return null;
  }

  void requestPv() {}

  Future<void> dispose() async {
    if (!_outputController.isClosed) {
      await _outputController.close();
    }
    if (!_stateController.isClosed) {
      await _stateController.close();
    }
    _state = StockfishState.disposed;
  }
}
